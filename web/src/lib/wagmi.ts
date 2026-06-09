"use client";

import { createConfig, http } from "wagmi";
import { injected } from "wagmi/connectors";
import { monadTestnet } from "./chains";
import { getInjectedProvider } from "./ethereum";

export const wagmiConfig = createConfig({
  chains: [monadTestnet],
  connectors: [
    injected({
      shimDisconnect: true,
      unstable_shimAsyncInject: 1000,
      target() {
        const provider = getInjectedProvider();
        if (!provider) return undefined;
        return {
          id: "metaMask",
          name: "MetaMask",
          provider,
        };
      },
    }),
  ],
  transports: {
    [monadTestnet.id]: http(
      process.env.NEXT_PUBLIC_MONAD_RPC_URL ?? "https://testnet-rpc.monad.xyz",
    ),
  },
  ssr: true,
});
