#!/usr/bin/env bash
# Seed SwarmFi on Monad testnet — requires PRIVATE_KEY for deployer in env or .env
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RPC="${RPC_URL:-https://testnet-rpc.monad.xyz}"

ORACLE="0x6931e02f0ae958E6A3a3485a6782Dde8c00E2Bc6"
MARKET="0x69a30e394b99989f1f3c519758fbD54425d2C113"
VAULT="0x6A4D777a02A346e8b877f6D1f3dae73114304c61"
REPUTATION="0xF3B271e7aEeCCA0d110431b17B9142e9fF68720d"
DEPLOYER="0x4c10043F68F7d9ADF6CeeCFD2A7eC82bB19C8937"

BTC_PAIR="0xee62665949c883f9e0f6f002eac32e00bd59dfe6c34e92a91c37d6a8322d6489"
STAKE="0.1ether"
FUND_AMOUNT="0.25ether"

if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$ROOT/.env"
  set +a
fi

if [[ -z "${PRIVATE_KEY:-}" ]]; then
  echo "ERROR: Set PRIVATE_KEY in contracts/.env or export PRIVATE_KEY (deployer key for $DEPLOYER)"
  exit 1
fi

export PATH="${HOME}/.foundry/bin:${PATH}"
command -v cast >/dev/null || { echo "Install Foundry first"; exit 1; }

if ! cast wallet address --private-key "$PRIVATE_KEY" >/dev/null 2>&1; then
  echo "ERROR: PRIVATE_KEY in .env is invalid (still a placeholder?)"
  echo "       Edit contracts/.env with your real 64-char hex key for $DEPLOYER"
  exit 1
fi

DEPLOYER_FROM_KEY=$(cast wallet address --private-key "$PRIVATE_KEY")
DEPLOYER_LC=$(echo "$DEPLOYER" | tr '[:upper:]' '[:lower:]')
DEPLOYER_KEY_LC=$(echo "$DEPLOYER_FROM_KEY" | tr '[:upper:]' '[:lower:]')
if [[ "$DEPLOYER_KEY_LC" != "$DEPLOYER_LC" ]]; then
  echo "WARNING: PRIVATE_KEY address ($DEPLOYER_FROM_KEY) != expected deployer ($DEPLOYER)"
fi

echo "==> Deployer: $DEPLOYER"
echo "==> RPC: $RPC"

# Three ephemeral agent wallets for oracle consensus (distinct addresses required)
echo "==> Creating 3 agent wallets..."
AGENT1_JSON=$(cast wallet new --json)
AGENT2_JSON=$(cast wallet new --json)
AGENT3_JSON=$(cast wallet new --json)

AGENT1_KEY=$(echo "$AGENT1_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['private_key'])")
AGENT1_ADDR=$(echo "$AGENT1_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['address'])")
AGENT2_KEY=$(echo "$AGENT2_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['private_key'])")
AGENT2_ADDR=$(echo "$AGENT2_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['address'])")
AGENT3_KEY=$(echo "$AGENT3_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['private_key'])")
AGENT3_ADDR=$(echo "$AGENT3_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['address'])")

echo "    Agent Alpha: $AGENT1_ADDR"
echo "    Agent Beta:  $AGENT2_ADDR"
echo "    Agent Gamma: $AGENT3_ADDR"

register_agent() {
  local key=$1 name=$2
  cast send "$ORACLE" "registerAgent(string,uint8)" "$name" 0 \
    --value "$STAKE" --rpc-url "$RPC" --private-key "$key" --gas-limit 500000
}

submit_price() {
  local key=$1 price=$2 conf=$3
  cast send "$ORACLE" "submitPrice(bytes32,uint256,uint8)" "$BTC_PAIR" "$price" "$conf" \
    --rpc-url "$RPC" --private-key "$key" --gas-limit 500000
}

echo "==> Funding agents from deployer..."
for addr in "$AGENT1_ADDR" "$AGENT2_ADDR" "$AGENT3_ADDR"; do
  cast send "$addr" --value "$FUND_AMOUNT" --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --gas-limit 100000
  sleep 2
done

echo "==> Registering agents on ReputationRegistry (admin)..."
for addr in "$AGENT1_ADDR" "$AGENT2_ADDR" "$AGENT3_ADDR"; do
  cast send "$REPUTATION" "registerAgent(address)" "$addr" \
    --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --gas-limit 200000
  sleep 1
done

echo "==> Registering agents on SwarmOracle..."
register_agent "$AGENT1_KEY" "Alpha"
sleep 2
register_agent "$AGENT2_KEY" "Beta"
sleep 2
register_agent "$AGENT3_KEY" "Gamma"
sleep 2

echo "==> Submitting BTC/USD prices..."
submit_price "$AGENT1_KEY" 10000000000000 90    # $100,000
sleep 2
submit_price "$AGENT2_KEY" 10010000000000 85    # $100,100
sleep 2
submit_price "$AGENT3_KEY" 9990000000000 88     # $99,900
sleep 2

echo "==> Running consensus..."
cast send "$ORACLE" "runConsensus(bytes32)" "$BTC_PAIR" \
  --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --gas-limit 2000000
sleep 2

CONSENSUS=$(cast call "$ORACLE" "getLatestConsensus(bytes32)(uint256,uint64,bool)" "$BTC_PAIR" --rpc-url "$RPC")
echo "    Consensus result: $CONSENSUS"

END_TIME=$(($(date +%s) + 604800))
echo "==> Creating prediction market (ends in 7 days)..."
cast send "$MARKET" \
  "createMarket(string,string,string,string,uint64,bytes32,uint256)" \
  "Will BTC stay above \$100k this week?" \
  "Resolved via SwarmOracle BTC/USD consensus" \
  "Yes" "No" \
  "$END_TIME" "$BTC_PAIR" 10000000000000 \
  --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --gas-limit 800000
sleep 2

echo "==> Creating Balanced vault..."
cast send "$VAULT" "createVault(string,uint8)" "SwarmFi Balanced" 1 \
  --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --gas-limit 500000

MARKET_COUNT=$(cast call "$MARKET" "marketCount()(uint256)" --rpc-url "$RPC")
VAULT_COUNT=$(cast call "$VAULT" "vaultCount()(uint256)" --rpc-url "$RPC")

echo ""
echo "========================================"
echo "SEED COMPLETE"
echo "========================================"
echo "Agents:"
echo "  Alpha: $AGENT1_ADDR"
echo "  Beta:  $AGENT2_ADDR"
echo "  Gamma: $AGENT3_ADDR"
echo "Market ID: $MARKET_COUNT"
echo "Vault ID:  $VAULT_COUNT"
echo "BTC/USD pair: $BTC_PAIR"
echo ""
echo "Save agent keys locally if you need them again (testnet only)."

# Update deployments seed file (addresses only, no keys)
SEED_FILE="$ROOT/../deployments/seed-agents.json"
cat > "$SEED_FILE" <<EOF
{
  "agents": [
    {"name": "Alpha", "address": "$AGENT1_ADDR"},
    {"name": "Beta", "address": "$AGENT2_ADDR"},
    {"name": "Gamma", "address": "$AGENT3_ADDR"}
  ],
  "marketId": "$MARKET_COUNT",
  "vaultId": "$VAULT_COUNT",
  "btcUsdPair": "$BTC_PAIR"
}
EOF
echo "Wrote $SEED_FILE"
