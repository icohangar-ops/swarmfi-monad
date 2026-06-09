"use client";

import { useCallback, useEffect, useState } from "react";
import {
  useAccount,
  useConnect,
  useConnectors,
  useDisconnect,
  useSwitchChain,
} from "wagmi";
import { monadTestnet } from "@/lib/chains";
import { hasInjectedProvider } from "@/lib/ethereum";

export function ConnectWallet() {
  const [mounted, setMounted] = useState(false);
  const [walletAvailable, setWalletAvailable] = useState(false);
  const { address, isConnected, chainId } = useAccount();
  const connectors = useConnectors();
  const { mutate: connect, isPending, error, reset } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain, isPending: isSwitching } = useSwitchChain();

  useEffect(() => {
    setMounted(true);
    setWalletAvailable(hasInjectedProvider());
  }, []);

  const pickConnector = useCallback(() => {
    return (
      connectors.find((c) => c.id === "metaMask") ??
      connectors.find((c) => c.type === "injected") ??
      connectors[0]
    );
  }, [connectors]);

  const handleConnect = useCallback(() => {
    reset();

    if (!hasInjectedProvider()) {
      window.alert(
        "No wallet extension found.\n\n1. Install MetaMask\n2. Open this app in Chrome or Brave (not Cursor preview)\n3. Refresh the page",
      );
      return;
    }

    const connector = pickConnector();
    if (!connector) {
      window.alert("No wallet connector available. Refresh the page and try again.");
      return;
    }

    connect(
      { connector, chainId: monadTestnet.id },
      {
        onSuccess: (data) => {
          if (data.chainId !== monadTestnet.id) {
            switchChain({ chainId: monadTestnet.id });
          }
        },
      },
    );
  }, [connect, pickConnector, reset, switchChain]);

  useEffect(() => {
    if (!isConnected || !chainId || chainId === monadTestnet.id) return;
    switchChain({ chainId: monadTestnet.id });
  }, [isConnected, chainId, switchChain]);

  if (!mounted) {
    return (
      <div className="h-9 w-28 animate-pulse rounded-lg bg-violet-900/40" />
    );
  }

  if (isConnected && address) {
    const wrongChain = chainId !== monadTestnet.id;
    return (
      <div className="flex items-center gap-2">
        {wrongChain ? (
          <button
            type="button"
            onClick={() => switchChain({ chainId: monadTestnet.id })}
            disabled={isSwitching}
            className="rounded-lg bg-amber-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-amber-500 disabled:opacity-50"
          >
            Switch to Monad
          </button>
        ) : null}
        <button
          type="button"
          onClick={() => disconnect()}
          className="rounded-lg border border-violet-500/40 px-3 py-1.5 text-xs text-violet-200 hover:bg-violet-900/40"
        >
          {address.slice(0, 6)}…{address.slice(-4)}
        </button>
      </div>
    );
  }

  const noWallet = !walletAvailable;

  return (
    <div className="flex flex-col items-end gap-1">
      <button
        type="button"
        disabled={isPending || noWallet}
        onClick={handleConnect}
        className="rounded-lg bg-violet-600 px-4 py-2 text-sm font-medium text-white hover:bg-violet-500 disabled:opacity-50"
      >
        {isPending ? "Connecting…" : "Connect Wallet"}
      </button>
      {noWallet ? (
        <p className="max-w-[220px] text-right text-xs text-amber-200/90">
          Open in Chrome/Brave with MetaMask installed, then refresh
        </p>
      ) : null}
      {error ? (
        <p className="max-w-[220px] text-right text-xs text-red-300">
          {error instanceof Error ? error.message : "Connection failed"}
        </p>
      ) : null}
    </div>
  );
}
