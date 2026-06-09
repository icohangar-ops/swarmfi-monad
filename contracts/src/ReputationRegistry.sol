// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IReputationRegistry} from "./interfaces/IReputationRegistry.sol";

/// @title ReputationRegistry — on-chain agent reputation tiers for SwarmFi
contract ReputationRegistry is Ownable, IReputationRegistry {
    uint256 public constant MAX_SCORE = 1000;

    struct AgentReputation {
        uint32 totalTasks;
        uint32 successfulTasks;
        uint256 accuracyScore;
        uint256 reliabilityScore;
        Tier tier;
        uint64 updatedAt;
    }

    mapping(address => AgentReputation) public agents;
    mapping(address => bool) public authorizedUpdaters;

    uint32 public agentCount;

    event ReputationUpdated(address indexed agent, uint256 accuracyScore, Tier tier);
    event UpdaterAuthorized(address indexed updater, bool authorized);

    error UnauthorizedUpdater();
    error InvalidScore();

    constructor(address admin) Ownable(admin) {}

    function authorizeUpdater(address updater, bool authorized) external onlyOwner {
        authorizedUpdaters[updater] = authorized;
        emit UpdaterAuthorized(updater, authorized);
    }

    function getAccuracyScore(address agent) external view returns (uint256) {
        return agents[agent].accuracyScore;
    }

    function getWeightMultiplier(address agent) external view returns (uint256) {
        return _weightMultiplier(agents[agent].tier);
    }

    function recordOracleOutcome(address agent, bool successful, int256 accuracyDelta) external {
        if (!authorizedUpdaters[msg.sender]) revert UnauthorizedUpdater();
        _touchAgent(agent);

        AgentReputation storage rep = agents[agent];
        rep.totalTasks += 1;
        if (successful) rep.successfulTasks += 1;

        if (accuracyDelta > 0) {
            uint256 delta = uint256(accuracyDelta);
            rep.accuracyScore = rep.accuracyScore + delta > MAX_SCORE ? MAX_SCORE : rep.accuracyScore + delta;
        } else if (accuracyDelta < 0) {
            uint256 delta = uint256(-accuracyDelta);
            rep.accuracyScore = delta >= rep.accuracyScore ? 0 : rep.accuracyScore - delta;
        }

        rep.reliabilityScore = rep.totalTasks == 0
            ? 0
            : (uint256(rep.successfulTasks) * 10_000) / rep.totalTasks;
        rep.tier = _tierFromScore(rep.accuracyScore);
        rep.updatedAt = uint64(block.timestamp);

        emit ReputationUpdated(agent, rep.accuracyScore, rep.tier);
    }

    function registerAgent(address agent) external onlyOwner {
        _touchAgent(agent);
    }

    function _touchAgent(address agent) internal {
        if (agents[agent].updatedAt == 0) {
            agents[agent] = AgentReputation({
                totalTasks: 0,
                successfulTasks: 0,
                accuracyScore: 500,
                reliabilityScore: 0,
                tier: Tier.Silver,
                updatedAt: uint64(block.timestamp)
            });
            agentCount += 1;
        }
    }

    function _tierFromScore(uint256 score) internal pure returns (Tier) {
        if (score >= 900) return Tier.Platinum;
        if (score >= 750) return Tier.Gold;
        if (score >= 500) return Tier.Silver;
        return Tier.Bronze;
    }

    function _weightMultiplier(Tier tier) internal pure returns (uint256) {
        if (tier == Tier.Platinum) return 800;
        if (tier == Tier.Gold) return 400;
        if (tier == Tier.Silver) return 200;
        return 100;
    }
}
