"use client";

import { StatCard } from "@/components/stat-card";
import {
  addresses,
  assetPairHash,
  formatPrice,
  swarmOracleAbi,
} from "@/lib/contracts";
import { useReadContract } from "wagmi";

const BTC_USD = assetPairHash("BTC/USD");

export default function DashboardPage() {
  const deployed = Boolean(addresses.swarmOracle);

  const { data: config } = useReadContract({
    address: addresses.swarmOracle,
    abi: swarmOracleAbi,
    functionName: "config",
    query: { enabled: deployed },
  });

  const { data: consensus } = useReadContract({
    address: addresses.swarmOracle,
    abi: swarmOracleAbi,
    functionName: "getLatestConsensus",
    args: [BTC_USD],
    query: { enabled: deployed },
  });

  const { data: roundCount } = useReadContract({
    address: addresses.swarmOracle,
    abi: swarmOracleAbi,
    functionName: "getConsensusRoundCount",
    query: { enabled: deployed },
  });

  const price = consensus?.[0];
  const computedAt = consensus?.[1];
  const exists = consensus?.[2];

  return (
    <div className="space-y-8">
      <section>
        <h1 className="text-3xl font-bold text-white">Swarm Oracle Dashboard</h1>
        <p className="mt-2 max-w-2xl text-violet-200/80">
          Weighted multi-agent consensus on Monad. Agents stake MON, submit prices, and
          participate in adversarial slashing rounds.
        </p>
      </section>

      {!deployed ? (
        <div className="rounded-2xl border border-amber-500/30 bg-amber-950/20 p-6 text-amber-100">
          <p className="font-medium">Contracts not configured</p>
          <p className="mt-2 text-sm text-amber-200/80">
            Deploy with Foundry, then set addresses in <code>web/.env.local</code> from{" "}
            <code>forge script script/Deploy.s.sol</code>.
          </p>
        </div>
      ) : null}

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          label="BTC/USD Consensus"
          value={exists && price ? `$${formatPrice(price)}` : "—"}
          hint={computedAt ? `Updated ${new Date(Number(computedAt) * 1000).toLocaleString()}` : "No round yet"}
        />
        <StatCard
          label="Consensus Rounds"
          value={roundCount?.toString() ?? "0"}
        />
        <StatCard
          label="Registered Agents"
          value={config ? String(config[4]) : "—"}
        />
        <StatCard
          label="Total Staked"
          value={config ? `${Number(config[5]) / 1e18} MON` : "—"}
        />
      </div>

      <section className="rounded-2xl border border-violet-500/20 bg-violet-950/20 p-6">
        <h2 className="text-lg font-semibold text-white">Architecture</h2>
        <ul className="mt-4 grid gap-2 text-sm text-violet-200/90 sm:grid-cols-2">
          <li>SwarmOracle — weighted median consensus + slashing</li>
          <li>ReputationRegistry — Bronze → Platinum tiers</li>
          <li>PredictionMarket — parimutuel markets via oracle</li>
          <li>VaultManager — share-based vaults + agent rebalance</li>
        </ul>
      </section>
    </div>
  );
}
