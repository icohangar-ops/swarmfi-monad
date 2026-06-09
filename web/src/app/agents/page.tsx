"use client";

import { useState } from "react";
import { parseEther } from "viem";
import { addresses, assetPairHash, swarmOracleAbi } from "@/lib/contracts";
import { useWriteContract, useWaitForTransactionReceipt } from "wagmi";

export default function AgentsPage() {
  const [name, setName] = useState("Swarm Agent");
  const [agentType, setAgentType] = useState(0);
  const [stake, setStake] = useState("0.1");
  const [price, setPrice] = useState("100000");
  const [confidence, setConfidence] = useState("90");

  const deployed = Boolean(addresses.swarmOracle);
  const BTC_USD = assetPairHash("BTC/USD");

  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: confirming } = useWaitForTransactionReceipt({ hash });

  function register() {
    writeContract({
      address: addresses.swarmOracle,
      abi: swarmOracleAbi,
      functionName: "registerAgent",
      args: [name, agentType],
      value: parseEther(stake),
    });
  }

  function submitPrice() {
    const scaled = BigInt(price) * 100_000_000n;
    writeContract({
      address: addresses.swarmOracle,
      abi: swarmOracleAbi,
      functionName: "submitPrice",
      args: [BTC_USD, scaled, Number(confidence)],
    });
  }

  function runConsensus() {
    writeContract({
      address: addresses.swarmOracle,
      abi: swarmOracleAbi,
      functionName: "runConsensus",
      args: [BTC_USD],
    });
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-white">Agents</h1>
        <p className="mt-2 text-violet-200/80">
          Register as an oracle agent, submit BTC/USD feeds, and trigger consensus rounds.
        </p>
      </div>

      {!deployed ? (
        <p className="text-amber-200">Set NEXT_PUBLIC_SWARM_ORACLE in .env.local</p>
      ) : (
        <div className="grid gap-6 lg:grid-cols-3">
          <AgentPanel title="1. Register" onSubmit={register} disabled={isPending || confirming}>
            <Field label="Name" value={name} onChange={setName} />
            <Field label="Type (0=Price)" value={String(agentType)} onChange={(v) => setAgentType(Number(v))} />
            <Field label="Stake (MON)" value={stake} onChange={setStake} />
          </AgentPanel>

          <AgentPanel title="2. Submit price" onSubmit={submitPrice} disabled={isPending || confirming}>
            <Field label="BTC price (USD)" value={price} onChange={setPrice} />
            <Field label="Confidence (0-255)" value={confidence} onChange={setConfidence} />
          </AgentPanel>

          <AgentPanel title="3. Run consensus" onSubmit={runConsensus} disabled={isPending || confirming}>
            <p className="text-sm text-violet-300/80">
              Requires ≥3 agents with fresh BTC/USD submissions. Computes weighted median.
            </p>
          </AgentPanel>
        </div>
      )}

      {error ? (
        <p className="text-sm text-red-300">{(error as Error).message}</p>
      ) : null}
    </div>
  );
}

function AgentPanel({
  title,
  children,
  onSubmit,
  disabled,
}: {
  title: string;
  children: React.ReactNode;
  onSubmit: () => void;
  disabled: boolean;
}) {
  return (
    <div className="rounded-2xl border border-violet-500/20 bg-violet-950/30 p-6">
      <h2 className="font-semibold text-white">{title}</h2>
      <div className="mt-4 space-y-3">{children}</div>
      <button
        type="button"
        onClick={onSubmit}
        disabled={disabled}
        className="mt-4 w-full rounded-lg bg-violet-600 py-2 text-sm font-medium text-white hover:bg-violet-500 disabled:opacity-50"
      >
        Submit
      </button>
    </div>
  );
}

function Field({
  label,
  value,
  onChange,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
}) {
  return (
    <label className="block text-sm text-violet-300">
      {label}
      <input
        className="mt-1 w-full rounded-lg border border-violet-500/30 bg-black/30 px-3 py-2"
        value={value}
        onChange={(e) => onChange(e.target.value)}
      />
    </label>
  );
}
