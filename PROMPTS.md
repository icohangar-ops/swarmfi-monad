# SwarmFi on Monad — copy-paste prompts

Deployer wallet (testnet): `0x4c10043F68F7d9ADF6CeeCFD2A7eC82bB19C8937`

---

## Terminal commands (run yourself)

### 1. Fund wallet

Open https://testnet.monad.xyz and request MON for:

`0x4c10043F68F7d9ADF6CeeCFD2A7eC82bB19C8937`

### 2. Deploy contracts

```bash
cd ~/Projects/swarmfi-monad/contracts

forge script script/Deploy.s.sol:DeploySwarmFi \
  --rpc-url https://testnet-rpc.monad.xyz \
  --private-key <YOUR_PRIVATE_KEY_FOR_0x4c10043F> \
  --broadcast
```

### 3. Update env with deployed addresses

Paste the four addresses from deploy output into `web/.env.local`.

### 4. Run frontend

```bash
cd ~/Projects/swarmfi-monad/web
npm run dev
```

Open http://localhost:3000 — connect MetaMask with Monad Testnet (chain ID 10143).

---

## Cursor agent prompts (paste into chat)

### After deploy — wire addresses

```
Deploy finished. Here are my contract addresses:
- ReputationRegistry: 0x...
- SwarmOracle: 0x...
- PredictionMarket: 0x...
- VaultManager: 0x...

Update web/.env.local and deployments/monad-testnet.json, then verify the frontend reads them.
```

### Seed demo data on testnet

```
Using monskills, seed SwarmFi on Monad testnet for wallet 0x4c10043F68F7d9ADF6CeeCFD2A7eC82bB19C8937:
1. Register 3 oracle agents with 0.1 MON stake each
2. Submit BTC/USD prices from each agent
3. Run consensus
4. Create one prediction market and one Balanced vault
Use cast commands against the deployed contracts in deployments/monad-testnet.json
```

### Verify contracts on explorers

```
Using monskill scaffold verification API, verify all four SwarmFi contracts on Monad testnet (chainId 10143). Addresses are in deployments/monad-testnet.json.
```

### Add Para wallet (optional)

```
Using monskill wallet-integration, add Para embedded wallet to swarmfi-monad/web with Monad testnet wiring. Frontend is already scaffolded with wagmi.
```

### Blitz showcase submission

```
Help me write a Blitz showcase entry for SwarmFi on Monad: multi-agent oracle, prediction markets, reputation registry, vault manager. Deployer 0x4c10043F68F7d9ADF6CeeCFD2A7eC82bB19C8937, live demo at localhost:3000.
```
