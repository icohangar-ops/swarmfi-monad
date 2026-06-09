# Seed SwarmFi on Monad Testnet

**Admin / deployer:** `0x4c10043F68F7d9ADF6CeeCFD2A7eC82bB19C8937`

## One-command seed (recommended)

```bash
cd ~/Projects/swarmfi-monad/contracts

# Ensure .env has your REAL private key (64 hex chars), not a placeholder
nano .env

set -a && source .env && set +a
./scripts/seed-testnet.sh
```

The script will:
1. Create 3 agent wallets
2. Fund them from deployer (~0.25 MON each)
3. Register agents + submit BTC/USD prices
4. Run consensus
5. Create prediction market #1 + Balanced vault #1

Output: `deployments/seed-agents.json`

---

## Manual cast commands

```bash
export PATH="$HOME/.foundry/bin:$PATH"
export RPC=https://testnet-rpc.monad.xyz
export PK=<your_deployer_private_key>

export ORACLE=0x6931e02f0ae958E6A3a3485a6782Dde8c00E2Bc6
export MARKET=0x69a30e394b99989f1f3c519758fbD54425d2C113
export VAULT=0x6A4D777a02A346e8b877f6D1f3dae73114304c61
export REPUTATION=0xF3B271e7aEeCCA0d110431b17B9142e9fF68720d
export BTC=0xee62665949c883f9e0f6f002eac32e00bd59dfe6c34e92a91c37d6a8322d6489

# Create & fund 3 agents (save keys from cast wallet new --json)
# Then per agent: registerAgent, submitPrice, finally runConsensus from deployer
```

---

## After seeding

```bash
cd ~/Projects/swarmfi-monad/web && npm run dev
```

- Dashboard → BTC/USD consensus price
- Markets → market ID 1
- Vaults → vault ID 1
