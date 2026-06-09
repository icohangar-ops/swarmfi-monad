#!/usr/bin/env python3
"""Off-chain price agent for SwarmFi on Monad.

Submits BTC/USD price feeds to SwarmOracle via web3.py.
Run after contracts are deployed and agent is registered on-chain.
"""

from __future__ import annotations

import os
import time

# Example: wire to SwarmOracle.submitPrice(bytes32, uint256, uint8)
# Requires PRIVATE_KEY, RPC_URL, SWARM_ORACLE_ADDRESS env vars.

ASSET_PAIR = "BTC/USD"
DEFAULT_PRICE_USD = 100_000
PRICE_SCALE = 100_000_000


def main() -> None:
    rpc = os.environ.get("RPC_URL", "https://testnet-rpc.monad.xyz")
    oracle = os.environ.get("SWARM_ORACLE_ADDRESS", "")
    if not oracle:
        raise SystemExit("Set SWARM_ORACLE_ADDRESS")

    print(f"SwarmFi price agent — RPC {rpc}")
    print(f"Oracle: {oracle}")
    print(f"Would submit {ASSET_PAIR} @ ${DEFAULT_PRICE_USD} (scale {PRICE_SCALE})")
    print("Integrate web3.py + account signing for production runs.")
    time.sleep(0)


if __name__ == "__main__":
    main()
