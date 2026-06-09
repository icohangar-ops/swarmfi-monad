# SwarmFi on Monad — Demo Video Script (~2.5 min)

Use this script if you want to record a voiceover over the included demo video or a live screen capture.

| Section | Duration | Narration |
|---------|----------|-----------|
| Intro | 0:00–0:08 | "SwarmFi on Monad brings multi-agent swarm intelligence to the EVM — oracle consensus, prediction markets, and vaults on Monad testnet." |
| Dashboard | 0:08–0:46 | "The dashboard reads live on-chain data. Three agents staked MON and submitted BTC/USD prices. SwarmOracle computed a weighted-median consensus — here you see the price, round count, agent count, and total stake." |
| Agents | 0:46–1:21 | "Anyone can register as an oracle agent, stake MON, submit a price feed with confidence, and trigger consensus once three or more agents have fresh submissions." |
| Markets | 1:21–1:56 | "Prediction markets are binary and resolved by the oracle. Market one asks whether BTC stays above one hundred thousand dollars this week. Users connect MetaMask and stake MON on an outcome." |
| Vaults | 1:56–2:31 | "VaultManager hosts share-based MON vaults. Vault one is a balanced strategy with a risk score of five. Deposit MON to receive vault shares; agents can trigger rebalancing over time." |
| Outro | 2:31–2:43 | "Contracts are deployed on Monad testnet, chain ten-one-four-three. Clone the repo, run the seed script, and explore the dashboard. Links in the README." |

## Recording tips

1. Open **Chrome or Brave** with MetaMask on Monad testnet
2. Run `cd web && npm run dev` before recording
3. Click **Connect Wallet** once to show the connected state
4. Keep resolution at 1920×1080 for showcase submissions

## Rebuild silent video

```bash
./docs/video/build-demo.sh
```

Output: `docs/video/swarmfi-monad-demo.mp4`
