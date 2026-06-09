"use client";

import { useState } from "react";
import { formatEther, parseEther } from "viem";
import { addresses, vaultManagerAbi } from "@/lib/contracts";
import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from "wagmi";

const strategies = ["Conservative", "Balanced", "Aggressive"];

export default function VaultsPage() {
  const [vaultId, setVaultId] = useState("1");
  const [depositAmount, setDepositAmount] = useState("0.5");

  const deployed = Boolean(addresses.vaultManager);
  const id = BigInt(vaultId || "0");

  const { data: vault } = useReadContract({
    address: addresses.vaultManager,
    abi: vaultManagerAbi,
    functionName: "vaults",
    args: [id],
    query: { enabled: deployed && id > 0n },
  });

  const { data: vaultCount } = useReadContract({
    address: addresses.vaultManager,
    abi: vaultManagerAbi,
    functionName: "vaultCount",
    query: { enabled: deployed },
  });

  const { writeContract, data: hash, isPending } = useWriteContract();
  const { isLoading: confirming } = useWaitForTransactionReceipt({ hash });

  function deposit() {
    writeContract({
      address: addresses.vaultManager,
      abi: vaultManagerAbi,
      functionName: "deposit",
      args: [id],
      value: parseEther(depositAmount),
    });
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-white">Vaults</h1>
        <p className="mt-2 text-violet-200/80">
          Share-based MON vaults with agent-triggered rebalancing. {vaultCount ? `${vaultCount} vaults` : ""}
        </p>
      </div>

      {!deployed ? (
        <p className="text-amber-200">Set NEXT_PUBLIC_VAULT_MANAGER in .env.local</p>
      ) : (
        <div className="grid gap-6 lg:grid-cols-2">
          <div className="rounded-2xl border border-violet-500/20 bg-violet-950/30 p-6">
            <h2 className="font-semibold text-white">Vault #{vaultId}</h2>
            {vault && vault[0] > 0n ? (
              <div className="mt-4 space-y-2 text-sm text-violet-100/90">
                <p className="text-base font-medium text-white">{vault[1]}</p>
                <p>Strategy: {strategies[Number(vault[2])] ?? "Unknown"}</p>
                <p>Total value: {formatEther(vault[4])} MON</p>
                <p>Total shares: {vault[5].toString()}</p>
                <p>Risk score: {vault[6]}/10</p>
                <p>Rebalances: {vault[7]}</p>
              </div>
            ) : (
              <p className="mt-4 text-sm text-violet-300">No vault at this ID</p>
            )}
          </div>

          <div className="rounded-2xl border border-violet-500/20 bg-violet-950/30 p-6">
            <h2 className="font-semibold text-white">Deposit</h2>
            <div className="mt-4 space-y-3">
              <label className="block text-sm text-violet-300">
                Vault ID
                <input
                  className="mt-1 w-full rounded-lg border border-violet-500/30 bg-black/30 px-3 py-2"
                  value={vaultId}
                  onChange={(e) => setVaultId(e.target.value)}
                />
              </label>
              <label className="block text-sm text-violet-300">
                Amount (MON)
                <input
                  className="mt-1 w-full rounded-lg border border-violet-500/30 bg-black/30 px-3 py-2"
                  value={depositAmount}
                  onChange={(e) => setDepositAmount(e.target.value)}
                />
              </label>
              <button
                type="button"
                onClick={deposit}
                disabled={isPending || confirming}
                className="w-full rounded-lg bg-violet-600 py-2 font-medium text-white hover:bg-violet-500 disabled:opacity-50"
              >
                {isPending || confirming ? "Depositing…" : "Deposit"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
