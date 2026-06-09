import { keccak256, stringToBytes } from "viem";

export const addresses = {
  reputationRegistry: (process.env.NEXT_PUBLIC_REPUTATION_REGISTRY ?? "") as `0x${string}`,
  swarmOracle: (process.env.NEXT_PUBLIC_SWARM_ORACLE ?? "") as `0x${string}`,
  predictionMarket: (process.env.NEXT_PUBLIC_PREDICTION_MARKET ?? "") as `0x${string}`,
  vaultManager: (process.env.NEXT_PUBLIC_VAULT_MANAGER ?? "") as `0x${string}`,
};

export const swarmOracleAbi = [
  {
    type: "function",
    name: "registerAgent",
    stateMutability: "payable",
    inputs: [
      { name: "name", type: "string" },
      { name: "agentType", type: "uint8" },
    ],
    outputs: [],
  },
  {
    type: "function",
    name: "submitPrice",
    stateMutability: "nonpayable",
    inputs: [
      { name: "assetPair", type: "bytes32" },
      { name: "price", type: "uint256" },
      { name: "confidence", type: "uint8" },
    ],
    outputs: [],
  },
  {
    type: "function",
    name: "runConsensus",
    stateMutability: "nonpayable",
    inputs: [{ name: "assetPair", type: "bytes32" }],
    outputs: [{ name: "consensusPrice", type: "uint256" }],
  },
  {
    type: "function",
    name: "getLatestConsensus",
    stateMutability: "view",
    inputs: [{ name: "assetPair", type: "bytes32" }],
    outputs: [
      { name: "price", type: "uint256" },
      { name: "computedAt", type: "uint64" },
      { name: "exists", type: "bool" },
    ],
  },
  {
    type: "function",
    name: "getConsensusRoundCount",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "uint256" }],
  },
  {
    type: "function",
    name: "config",
    stateMutability: "view",
    inputs: [],
    outputs: [
      { name: "minAgentsForConsensus", type: "uint32" },
      { name: "maxAgeSeconds", type: "uint64" },
      { name: "acceptableDeviationBps", type: "uint64" },
      { name: "slashRateBps", type: "uint64" },
      { name: "agentCount", type: "uint32" },
      { name: "totalStaked", type: "uint256" },
      { name: "consensusRoundCount", type: "uint256" },
      { name: "signalCount", type: "uint256" },
    ],
  },
] as const;

export const predictionMarketAbi = [
  {
    type: "function",
    name: "marketCount",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "uint256" }],
  },
  {
    type: "function",
    name: "getMarket",
    stateMutability: "view",
    inputs: [{ name: "marketId", type: "uint256" }],
    outputs: [
      {
        type: "tuple",
        components: [
          { name: "id", type: "uint256" },
          { name: "creator", type: "address" },
          { name: "question", type: "string" },
          { name: "description", type: "string" },
          { name: "outcomeA", type: "string" },
          { name: "outcomeB", type: "string" },
          { name: "endTime", type: "uint64" },
          { name: "poolA", type: "uint256" },
          { name: "poolB", type: "uint256" },
          { name: "totalVolume", type: "uint256" },
          { name: "status", type: "uint8" },
          { name: "winningOutcome", type: "uint8" },
          { name: "resolvedAt", type: "uint64" },
          { name: "oracleAssetPair", type: "bytes32" },
        ],
      },
    ],
  },
  {
    type: "function",
    name: "submitPrediction",
    stateMutability: "payable",
    inputs: [
      { name: "marketId", type: "uint256" },
      { name: "outcome", type: "uint8" },
    ],
    outputs: [],
  },
] as const;

export const vaultManagerAbi = [
  {
    type: "function",
    name: "vaultCount",
    stateMutability: "view",
    inputs: [],
    outputs: [{ type: "uint256" }],
  },
  {
    type: "function",
    name: "vaults",
    stateMutability: "view",
    inputs: [{ name: "vaultId", type: "uint256" }],
    outputs: [
      { name: "id", type: "uint256" },
      { name: "name", type: "string" },
      { name: "strategy", type: "uint8" },
      { name: "owner", type: "address" },
      { name: "totalValue", type: "uint256" },
      { name: "totalShares", type: "uint256" },
      { name: "riskScore", type: "uint8" },
      { name: "rebalanceCount", type: "uint32" },
      { name: "isActive", type: "bool" },
      { name: "createdAt", type: "uint64" },
      { name: "lastRebalanceAt", type: "uint64" },
    ],
  },
  {
    type: "function",
    name: "deposit",
    stateMutability: "payable",
    inputs: [{ name: "vaultId", type: "uint256" }],
    outputs: [],
  },
] as const;

export function assetPairHash(pair: string): `0x${string}` {
  return keccak256(stringToBytes(pair));
}

export function formatPrice(scaled: bigint): string {
  const whole = scaled / 100_000_000n;
  const frac = scaled % 100_000_000n;
  return `${whole}.${frac.toString().padStart(8, "0").replace(/0+$/, "") || "0"}`;
}
