import type { EIP1193Provider } from "viem";

type EthereumProvider = EIP1193Provider & {
  isMetaMask?: boolean;
  providers?: EthereumProvider[];
};

export function getInjectedProvider(): EthereumProvider | undefined {
  if (typeof window === "undefined") return undefined;

  const ethereum = (window as Window & { ethereum?: EthereumProvider })
    .ethereum;
  if (!ethereum) return undefined;

  if (ethereum.providers?.length) {
    return (
      ethereum.providers.find((p) => p.isMetaMask) ?? ethereum.providers[0]
    );
  }

  return ethereum;
}

export function hasInjectedProvider(): boolean {
  return Boolean(getInjectedProvider());
}
