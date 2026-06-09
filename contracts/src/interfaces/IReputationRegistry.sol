// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IReputationRegistry {
    enum Tier {
        Bronze,
        Silver,
        Gold,
        Platinum
    }

    function getAccuracyScore(address agent) external view returns (uint256);

    function getWeightMultiplier(address agent) external view returns (uint256);

    function recordOracleOutcome(address agent, bool successful, int256 accuracyDelta) external;
}
