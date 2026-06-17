# SwarmFi Web Dashboard

The web dashboard for SwarmFi, a multi-agent oracle and prediction-market protocol
on the Monad testnet. It connects a wallet, reads on-chain state from the SwarmFi
contracts, and surfaces agents, markets, and vaults.

## Tech stack

- [Next.js](https://nextjs.org) 16 (App Router) + React 19
- [wagmi](https://wagmi.sh) and [viem](https://viem.sh) for wallet connection and contract reads/writes
- [TanStack Query](https://tanstack.com/query) for async/cache state
- [Tailwind CSS](https://tailwindcss.com) v4
- TypeScript

## Pages

- `/` — overview dashboard
- `/agents` — registered oracle agents and reputation
- `/markets` — prediction markets
- `/vaults` — vault manager positions

## Getting started

1. Install dependencies:

   ```bash
   npm install
   ```

2. Configure the environment. Copy the example file and fill in the deployed
   contract addresses (see `../deployments/monad-testnet.json`):

   ```bash
   cp .env.example .env.local
   ```

   | Variable | Purpose |
   | --- | --- |
   | `NEXT_PUBLIC_REPUTATION_REGISTRY` | ReputationRegistry contract address |
   | `NEXT_PUBLIC_SWARM_ORACLE` | SwarmOracle contract address |
   | `NEXT_PUBLIC_PREDICTION_MARKET` | PredictionMarket contract address |
   | `NEXT_PUBLIC_VAULT_MANAGER` | VaultManager contract address |
   | `NEXT_PUBLIC_MONAD_RPC_URL` | Optional override for the Monad testnet RPC endpoint |

3. Run the development server:

   ```bash
   npm run dev
   ```

   Open [http://localhost:3000](http://localhost:3000) in a browser with a
   wallet (such as MetaMask) configured for the Monad testnet.

## Scripts

- `npm run dev` — start the dev server
- `npm run build` — production build
- `npm run start` — serve the production build
- `npm run lint` — run ESLint

## Deployment

The dashboard is a standard Next.js app and can be deployed to any Next.js host
(for example Vercel). Set the same `NEXT_PUBLIC_*` environment variables in the
deployment environment.
