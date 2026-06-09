// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ISwarmOracle {
    function getLatestConsensus(bytes32 assetPair) external view returns (uint256 price, uint64 computedAt, bool exists);

    function getConsensusRoundCount() external view returns (uint256);
}
