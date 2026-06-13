#!/usr/bin/env python3
"""Off-chain price agent for SwarmFi on Monad.

Polls a price source and submits BTC/USD feeds to ``SwarmOracle.submitPrice``
via web3.py. On-chain submission is wrapped in the resilient on-chain write
client (bounded retry + per-attempt gas bump, pinned nonce with refresh on
``nonce too low``, explicit tx-success assertion, and an idempotency guard so a
crashed-then-retried round never double-submits or wastes gas).

Run after contracts are deployed and the agent address is authorized on-chain.

Environment:
  PRIVATE_KEY            agent signing key (hex, 0x-prefixed) — required
  RPC_URL               Monad RPC endpoint (default: testnet)
  SWARM_ORACLE_ADDRESS  deployed SwarmOracle address — required
  POLL_INTERVAL_S       seconds between submissions (default: 30)
  PRICE_SOURCE_URL      optional HTTP price feed; falls back to DEFAULT_PRICE_USD
  IDEMPOTENCY_PATH      durable idempotency ledger path (default: ./.price_agent_idem.json)
"""

from __future__ import annotations

import json
import logging
import os
import signal
import sys
import time
import urllib.request

from web3 import Web3
from eth_account import Account

from cubiczan_resilience import FileIdempotencyStore, resilient
from resilient_onchain import (
    CircuitBreaker,
    FeeFields,
    NormalizedReceipt,
    SendOpts,
    StateResult,
    SubmitResult,
    TxContext,
    send_with_retry,
)

ASSET_PAIR = "BTC/USD"
DEFAULT_PRICE_USD = 100_000
PRICE_SCALE = 100_000_000  # 1e8, matches the contract's 8-decimal convention
# bytes32 key for the asset pair, matching the contract's keccak256 convention.
BTC_USD_KEY = Web3.keccak(text=ASSET_PAIR)
SUBMIT_ABI = [
    {
        "name": "submitPrice",
        "type": "function",
        "stateMutability": "nonpayable",
        "inputs": [
            {"name": "pair", "type": "bytes32"},
            {"name": "price", "type": "uint256"},
            {"name": "confidence", "type": "uint8"},
        ],
        "outputs": [],
    }
]


# ─── Structured JSON logging to stdout ──────────────────────────────


class _JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "ts": self.formatTime(record, "%Y-%m-%dT%H:%M:%S%z"),
            "level": record.levelname,
            "msg": record.getMessage(),
            "agent": "price_agent",
            "pair": ASSET_PAIR,
        }
        if record.exc_info:
            payload["exc"] = self.formatException(record.exc_info)
        for key, value in getattr(record, "extra_fields", {}).items():
            payload[key] = value
        return json.dumps(payload)


def _build_logger() -> logging.Logger:
    log = logging.getLogger("price_agent")
    log.setLevel(logging.INFO)
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(_JsonFormatter())
    log.handlers = [handler]
    log.propagate = False
    return log


LOG = _build_logger()


def _log(msg: str, **fields: object) -> None:
    LOG.info(msg, extra={"extra_fields": fields})


# ─── Graceful shutdown ──────────────────────────────────────────────


class _Shutdown:
    def __init__(self) -> None:
        self.requested = False

    def request(self, signum: int, _frame: object) -> None:
        self.requested = True
        _log("shutdown signal received", signal=signum)


# ─── Price source (resilient HTTP fetch w/ exponential backoff) ─────


@resilient(timeout=10.0, max_attempts=4, base_delay=0.5)
def _fetch_price(url: str) -> int:
    """Fetch the latest price in whole USD. Retried with full-jitter
    exponential backoff on transient HTTP/RPC errors via @resilient."""
    with urllib.request.urlopen(url, timeout=10) as resp:  # noqa: S310
        data = json.loads(resp.read().decode())
    return int(float(data["price"]))


def _current_price_usd() -> int:
    source = os.environ.get("PRICE_SOURCE_URL")
    if not source:
        return DEFAULT_PRICE_USD
    try:
        return _fetch_price(source)
    except Exception:  # noqa: BLE001 — price source failures must not crash the loop
        LOG.warning(
            "price source fetch failed, using default",
            exc_info=True,
            extra={"extra_fields": {}},
        )
        return DEFAULT_PRICE_USD


# ─── On-chain submission (resilient write client) ───────────────────


def _submit_round(
    w3: Web3,
    acct: "Account",
    contract: object,
    breaker: CircuitBreaker,
    idem: FileIdempotencyStore,
    price_usd: int,
    confidence: int,
) -> tuple[NormalizedReceipt, str]:
    price_scaled = price_usd * PRICE_SCALE
    chain_id = w3.eth.chain_id
    # One idempotency key per (price, minute) bucket: a crash-retry of the same
    # round short-circuits before spending gas, but distinct rounds still submit.
    idem_key = f"submitPrice:{price_scaled}:{int(time.time() // 60)}"

    def fetch_state() -> StateResult:
        return StateResult(
            nonce=w3.eth.get_transaction_count(acct.address),
            fee=FeeFields(gas_price=w3.eth.gas_price),
        )

    def sign_send(ctx: TxContext) -> SubmitResult:
        tx = contract.functions.submitPrice(
            BTC_USD_KEY, price_scaled, confidence
        ).build_transaction(
            {
                "from": acct.address,
                "nonce": ctx.nonce,
                "gasPrice": ctx.fee.gas_price,
                "chainId": chain_id,
            }
        )
        signed = acct.sign_transaction(tx)
        tx_hash = w3.eth.send_raw_transaction(signed.rawTransaction)

        def wait() -> NormalizedReceipt:
            rcpt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=120)
            return NormalizedReceipt(
                status=rcpt["status"], tx_hash=tx_hash.hex(), raw=rcpt
            )

        return SubmitResult(tx_hash=tx_hash.hex(), wait=wait)

    receipt = send_with_retry(
        fetch_state,
        sign_send,
        SendOpts(
            fee_mode="legacy",
            bump_factor=1.125,
            max_attempts=5,
            backoff_base_s=1.0,
            breaker=breaker,
            idempotency_key=idem_key,
            already_sent=idem.already_done,
            logger=lambda m: _log(m, layer="onchain"),
        ),
    )
    return receipt, idem_key


def main() -> None:
    rpc = os.environ.get("RPC_URL", "https://testnet-rpc.monad.xyz")
    oracle = os.environ.get("SWARM_ORACLE_ADDRESS", "")
    pk = os.environ.get("PRIVATE_KEY", "")
    if not oracle:
        raise SystemExit("Set SWARM_ORACLE_ADDRESS")
    if not pk:
        raise SystemExit("Set PRIVATE_KEY")

    poll_interval = float(os.environ.get("POLL_INTERVAL_S", "30"))
    idem_path = os.environ.get("IDEMPOTENCY_PATH", ".price_agent_idem.json")

    w3 = Web3(Web3.HTTPProvider(rpc))
    acct = Account.from_key(pk)
    contract = w3.eth.contract(
        address=Web3.to_checksum_address(oracle), abi=SUBMIT_ABI
    )
    breaker = CircuitBreaker(threshold=5)
    idem = FileIdempotencyStore(idem_path)
    shutdown = _Shutdown()
    signal.signal(signal.SIGTERM, shutdown.request)
    signal.signal(signal.SIGINT, shutdown.request)

    _log(
        "price agent started",
        rpc=rpc,
        oracle=oracle,
        signer=acct.address,
        poll_interval_s=poll_interval,
    )

    while not shutdown.requested:
        price = _current_price_usd()
        try:
            receipt, idem_key = _submit_round(
                w3, acct, contract, breaker, idem, price, confidence=90
            )
            idem.mark_done(idem_key, receipt.tx_hash)
            _log(
                "price submitted",
                price_usd=price,
                tx_hash=receipt.tx_hash,
                status=receipt.status,
            )
        except Exception:  # noqa: BLE001 — one bad round must not kill the loop
            LOG.error(
                "submit round failed", exc_info=True, extra={"extra_fields": {}}
            )

        # Interruptible sleep so SIGTERM is honored promptly mid-interval.
        slept = 0.0
        while slept < poll_interval and not shutdown.requested:
            time.sleep(min(1.0, poll_interval - slept))
            slept += 1.0

    _log("price agent stopped cleanly")


if __name__ == "__main__":
    main()
