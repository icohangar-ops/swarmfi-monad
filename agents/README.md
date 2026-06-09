# Off-chain agents

Placeholder stubs for SwarmFi agent types. In production, these would run as autonomous services that:

- **Price agents** — fetch market data and call `SwarmOracle.submitPrice`
- **Risk agents** — monitor vault drawdowns and call `VaultManager.rebalance`
- **Contrarian agents** — submit dissenting feeds to improve consensus robustness

The testnet seed script (`contracts/scripts/seed-testnet.sh`) uses ephemeral Foundry wallets instead of these stubs.
