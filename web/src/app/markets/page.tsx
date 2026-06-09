"use client";

import { useState } from "react";
import { formatEther, parseEther } from "viem";
import {
  addresses,
  predictionMarketAbi,
} from "@/lib/contracts";
import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";

export default function MarketsPage() {
  const [marketId, setMarketId] = useState("1");
  const [outcome, setOutcome] = useState<0 | 1>(0);
  const [amount, setAmount] = useState("0.1");

  const deployed = Boolean(addresses.predictionMarket);
  const id = BigInt(marketId || "0");

  const { data: market } = useReadContract({
    address: addresses.predictionMarket,
    abi: predictionMarketAbi,
    functionName: "getMarket",
    args: [id],
    query: { enabled: deployed && id > 0n },
  });

  const { data: marketCount } = useReadContract({
    address: addresses.predictionMarket,
    abi: predictionMarketAbi,
    functionName: "marketCount",
    query: { enabled: deployed },
  });

  const { writeContract, data: hash, isPending } = useWriteContract();
  const { isLoading: confirming } = useWaitForTransactionReceipt({ hash });

  function predict() {
    writeContract({
      address: addresses.predictionMarket,
      abi: predictionMarketAbi,
      functionName: "submitPrediction",
      args: [id, outcome],
      value: parseEther(amount),
    });
  }

  const status = market ? ["Active", "Resolved", "Cancelled"][market.status] : "—";

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-white">Prediction Markets</h1>
        <p className="mt-2 text-violet-200/80">
          Binary markets resolved by SwarmOracle consensus. {marketCount ? `${marketCount} markets` : ""}
        </p>
      </div>

      {!deployed ? (
        <p className="text-amber-200">Set NEXT_PUBLIC_PREDICTION_MARKET in .env.local</p>
      ) : (
        <div className="grid gap-6 lg:grid-cols-2">
          <div className="rounded-2xl border border-violet-500/20 bg-violet-950/30 p-6">
            <h2 className="font-semibold text-white">Market #{marketId}</h2>
            {market ? (
              <div className="mt-4 space-y-2 text-sm text-violet-100/90">
                <p className="text-base font-medium text-white">{market.question}</p>
                <p>{market.description}</p>
                <p>Outcomes: {market.outcomeA} / {market.outcomeB}</p>
                <p>Status: {status}</p>
                <p>Pool A: {formatEther(market.poolA)} MON</p>
                <p>Pool B: {formatEther(market.poolB)} MON</p>
                <p>Volume: {formatEther(market.totalVolume)} MON</p>
              </div>
            ) : (
              <p className="mt-4 text-sm text-violet-300">No market at this ID</p>
            )}
          </div>

          <div className="rounded-2xl border border-violet-500/20 bg-violet-950/30 p-6">
            <h2 className="font-semibold text-white">Place prediction</h2>
            <div className="mt-4 space-y-3">
              <label className="block text-sm text-violet-300">
                Market ID
                <input
                  className="mt-1 w-full rounded-lg border border-violet-500/30 bg-black/30 px-3 py-2"
                  value={marketId}
                  onChange={(e) => setMarketId(e.target.value)}
                />
              </label>
              <label className="block text-sm text-violet-300">
                Outcome (0 = A, 1 = B)
                <select
                  className="mt-1 w-full rounded-lg border border-violet-500/30 bg-black/30 px-3 py-2"
                  value={outcome}
                  onChange={(e) => setOutcome(Number(e.target.value) as 0 | 1)}
                >
                  <option value={0}>Outcome A</option>
                  <option value={1}>Outcome B</option>
                </select>
              </label>
              <label className="block text-sm text-violet-300">
                Stake (MON)
                <input
                  className="mt-1 w-full rounded-lg border border-violet-500/30 bg-black/30 px-3 py-2"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                />
              </label>
              <button
                type="button"
                onClick={predict}
                disabled={isPending || confirming}
                className="w-full rounded-lg bg-violet-600 py-2 font-medium text-white hover:bg-violet-500 disabled:opacity-50"
              >
                {isPending || confirming ? "Submitting…" : "Submit prediction"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
