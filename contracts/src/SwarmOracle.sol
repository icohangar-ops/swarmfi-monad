// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IReputationRegistry} from "./interfaces/IReputationRegistry.sol";
import {ISwarmOracle} from "./interfaces/ISwarmOracle.sol";

/// @title SwarmOracle — weighted multi-agent price consensus on Monad
contract SwarmOracle is Ownable, ReentrancyGuard, ISwarmOracle {
    uint256 public constant PRICE_SCALE = 1e8;
    uint256 public constant BPS = 10_000;

    enum AgentType {
        Price,
        Risk,
        MarketMaker,
        Resolution
    }

    enum SignalType {
        PriceUpdate,
        RiskAlert,
        ConsensusReached,
        RebalanceRequest,
        MarketEvent,
        Heartbeat,
        AnomalyDetected
    }

    struct OracleConfig {
        uint32 minAgentsForConsensus;
        uint64 maxAgeSeconds;
        uint64 acceptableDeviationBps;
        uint64 slashRateBps;
        uint32 agentCount;
        uint256 totalStaked;
        uint256 consensusRoundCount;
        uint256 signalCount;
    }

    struct AgentNode {
        address authority;
        string name;
        AgentType agentType;
        uint256 stakeAmount;
        uint256 reputationScore;
        uint256 accuracyScore;
        uint256 totalSubmissions;
        bool isActive;
        uint64 registeredAt;
        uint64 lastSubmissionAt;
        uint32 slashCount;
    }

    struct PriceSubmission {
        uint256 price;
        uint8 confidence;
        address agent;
        uint256 weight;
        uint64 submittedAt;
        bool includedInConsensus;
    }

    struct ConsensusResult {
        uint256 consensusPrice;
        uint32 agentCount;
        uint8 confidence;
        uint64 computedAt;
        uint256 roundNumber;
        uint256 medianPrice;
        uint256 totalWeight;
    }

    struct StigmergySignal {
        SignalType signalType;
        address fromAgent;
        bytes32 dataHash;
        uint256 strength;
        uint256 decayRate;
        uint64 depositedAt;
        uint256 signalId;
    }

    OracleConfig public config;
    IReputationRegistry public reputationRegistry;

    /// @dev Hard cap on submissions accepted per round to bound runConsensus gas.
    uint256 public constant MAX_SUBMISSIONS_PER_ROUND = 256;

    mapping(address => AgentNode) public agents;
    mapping(bytes32 => PriceSubmission[]) private submissions;
    mapping(bytes32 => ConsensusResult) public latestConsensus;
    mapping(uint256 => StigmergySignal) public signals;

    /// @dev Current open submission round per asset pair (incremented each consensus run).
    mapping(bytes32 => uint256) public currentRound;
    /// @dev Last round in which a given agent submitted for a given asset pair.
    mapping(bytes32 => mapping(address => uint256)) public lastSubmittedRound;

    event AgentRegistered(address indexed agent, string name, uint256 stake);
    event PriceSubmitted(bytes32 indexed assetPair, address indexed agent, uint256 price, uint256 weight);
    event ConsensusComputed(bytes32 indexed assetPair, uint256 price, uint32 agents, uint256 round);
    event AgentSlashed(address indexed agent, uint256 amount, string reason);
    event StigmergyDeposited(uint256 indexed signalId, address indexed agent, SignalType signalType);

    error AgentExists();
    error AgentNotFound();
    error AgentInactive();
    error InsufficientStake();
    error NotEnoughAgents();
    error NoSubmissions();
    error DeviationTooHigh();
    error AlreadySubmittedThisRound();
    error TooManySubmissions();
    error TransferFailed();

    constructor(address admin, address reputationRegistry_) Ownable(admin) {
        reputationRegistry = IReputationRegistry(reputationRegistry_);
        config = OracleConfig({
            minAgentsForConsensus: 3,
            maxAgeSeconds: 300,
            acceptableDeviationBps: 500,
            slashRateBps: 1000,
            agentCount: 0,
            totalStaked: 0,
            consensusRoundCount: 0,
            signalCount: 0
        });
    }

    function registerAgent(string calldata name, AgentType agentType) external payable nonReentrant {
        if (agents[msg.sender].registeredAt != 0) revert AgentExists();
        if (msg.value < 0.01 ether) revert InsufficientStake();

        uint256 repScore = reputationRegistry.getAccuracyScore(msg.sender);
        if (repScore == 0) repScore = 500;

        agents[msg.sender] = AgentNode({
            authority: msg.sender,
            name: name,
            agentType: agentType,
            stakeAmount: msg.value,
            reputationScore: repScore,
            accuracyScore: repScore,
            totalSubmissions: 0,
            isActive: true,
            registeredAt: uint64(block.timestamp),
            lastSubmissionAt: 0,
            slashCount: 0
        });

        config.agentCount += 1;
        config.totalStaked += msg.value;

        emit AgentRegistered(msg.sender, name, msg.value);
    }

    function submitPrice(bytes32 assetPair, uint256 price, uint8 confidence) external {
        AgentNode storage agent = agents[msg.sender];
        if (agent.registeredAt == 0) revert AgentNotFound();
        if (!agent.isActive) revert AgentInactive();

        // Reject a second submission from the same agent in the same round.
        // currentRound starts at 0; lastSubmittedRound defaults to 0, so the
        // first submission is gated by also requiring a prior submission, hence
        // we mark using round + 1 to distinguish "never submitted" from round 0.
        uint256 round = currentRound[assetPair];
        if (lastSubmittedRound[assetPair][msg.sender] == round + 1) {
            revert AlreadySubmittedThisRound();
        }
        lastSubmittedRound[assetPair][msg.sender] = round + 1;

        // Bound the array so runConsensus can never be pushed out-of-gas.
        if (submissions[assetPair].length >= MAX_SUBMISSIONS_PER_ROUND) {
            revert TooManySubmissions();
        }

        uint256 weight = _computeWeight(msg.sender, agent.stakeAmount);
        submissions[assetPair].push(
            PriceSubmission({
                price: price,
                confidence: confidence,
                agent: msg.sender,
                weight: weight,
                submittedAt: uint64(block.timestamp),
                includedInConsensus: false
            })
        );

        agent.totalSubmissions += 1;
        agent.lastSubmissionAt = uint64(block.timestamp);

        emit PriceSubmitted(assetPair, msg.sender, price, weight);
    }

    function runConsensus(bytes32 assetPair) external returns (uint256 consensusPrice) {
        PriceSubmission[] storage subs = submissions[assetPair];
        uint256 len = subs.length;
        if (len < config.minAgentsForConsensus) revert NotEnoughAgents();

        uint64 cutoff = block.timestamp > config.maxAgeSeconds
            ? uint64(block.timestamp - config.maxAgeSeconds)
            : 0;
        uint256[] memory prices = new uint256[](len);
        uint256[] memory weights = new uint256[](len);
        uint256 valid;
        uint256 totalWeight;
        uint256 confidenceSum;

        for (uint256 i; i < len; ++i) {
            PriceSubmission storage sub = subs[i];
            if (sub.submittedAt < cutoff) continue;
            prices[valid] = sub.price;
            weights[valid] = sub.weight;
            totalWeight += sub.weight;
            confidenceSum += sub.confidence;
            sub.includedInConsensus = true;
            valid += 1;
        }

        if (valid == 0) revert NoSubmissions();

        consensusPrice = _weightedMedian(prices, weights, valid);
        uint256 median = _simpleMedian(prices, valid);
        uint8 avgConfidence = uint8(confidenceSum / valid);

        config.consensusRoundCount += 1;
        latestConsensus[assetPair] = ConsensusResult({
            consensusPrice: consensusPrice,
            agentCount: uint32(valid),
            confidence: avgConfidence,
            computedAt: uint64(block.timestamp),
            roundNumber: config.consensusRoundCount,
            medianPrice: median,
            totalWeight: totalWeight
        });

        for (uint256 i; i < len; ++i) {
            if (!subs[i].includedInConsensus) continue;
            bool ok = _withinDeviation(subs[i].price, consensusPrice);
            reputationRegistry.recordOracleOutcome(subs[i].agent, ok, ok ? int256(5) : int256(-15));
        }

        // Open a fresh round and clear this round's submissions. Clearing bounds
        // the array (preventing unbounded-growth gas DoS) and, together with the
        // incremented round id, lets each agent submit once in the next round.
        currentRound[assetPair] += 1;
        delete submissions[assetPair];

        emit ConsensusComputed(assetPair, consensusPrice, uint32(valid), config.consensusRoundCount);
    }

    function slashAgent(address agent, uint256 deviationBps, string calldata reason) external onlyOwner nonReentrant {
        AgentNode storage node = agents[agent];
        if (node.registeredAt == 0) revert AgentNotFound();
        if (deviationBps < config.acceptableDeviationBps) revert DeviationTooHigh();

        uint256 slashAmount = (node.stakeAmount * config.slashRateBps) / BPS;
        node.stakeAmount -= slashAmount;
        node.slashCount += 1;
        config.totalStaked -= slashAmount;
        node.isActive = node.stakeAmount >= 0.005 ether;

        (bool ok,) = payable(owner()).call{value: slashAmount}("");
        if (!ok) revert TransferFailed();
        emit AgentSlashed(agent, slashAmount, reason);
    }

    function submitStigmergySignal(
        SignalType signalType,
        bytes32 dataHash,
        uint256 strength,
        uint256 decayRate
    ) external {
        if (agents[msg.sender].registeredAt == 0) revert AgentNotFound();
        config.signalCount += 1;
        signals[config.signalCount] = StigmergySignal({
            signalType: signalType,
            fromAgent: msg.sender,
            dataHash: dataHash,
            strength: strength,
            decayRate: decayRate,
            depositedAt: uint64(block.timestamp),
            signalId: config.signalCount
        });
        emit StigmergyDeposited(config.signalCount, msg.sender, signalType);
    }

    function getLatestConsensus(bytes32 assetPair) external view returns (uint256 price, uint64 computedAt, bool exists) {
        ConsensusResult storage result = latestConsensus[assetPair];
        if (result.computedAt == 0) return (0, 0, false);
        return (result.consensusPrice, result.computedAt, true);
    }

    function getConsensusRoundCount() external view returns (uint256) {
        return config.consensusRoundCount;
    }

    function getSubmissionCount(bytes32 assetPair) external view returns (uint256) {
        return submissions[assetPair].length;
    }

    function _computeWeight(address agent, uint256 stake) internal view returns (uint256) {
        uint256 repMul = reputationRegistry.getWeightMultiplier(agent);
        return (stake * repMul) / 100;
    }

    function _withinDeviation(uint256 price, uint256 consensus) internal view returns (bool) {
        if (consensus == 0) return false;
        uint256 diff = price > consensus ? price - consensus : consensus - price;
        return (diff * BPS) / consensus <= config.acceptableDeviationBps;
    }

    function _weightedMedian(
        uint256[] memory prices,
        uint256[] memory weights,
        uint256 len
    ) internal pure returns (uint256) {
        for (uint256 i = 1; i < len; ++i) {
            uint256 keyP = prices[i];
            uint256 keyW = weights[i];
            int256 j = int256(i) - 1;
            while (j >= 0 && prices[uint256(j)] > keyP) {
                prices[uint256(j + 1)] = prices[uint256(j)];
                weights[uint256(j + 1)] = weights[uint256(j)];
                j--;
            }
            prices[uint256(j + 1)] = keyP;
            weights[uint256(j + 1)] = keyW;
        }

        uint256 half = _totalWeight(weights, len) / 2;
        uint256 cumulative;
        for (uint256 i; i < len; ++i) {
            cumulative += weights[i];
            if (cumulative >= half) return prices[i];
        }
        return prices[len - 1];
    }

    function _simpleMedian(uint256[] memory prices, uint256 len) internal pure returns (uint256) {
        if (len == 0) return 0;
        if (len % 2 == 1) return prices[len / 2];
        return (prices[len / 2 - 1] + prices[len / 2]) / 2;
    }

    function _totalWeight(uint256[] memory weights, uint256 len) internal pure returns (uint256 total) {
        for (uint256 i; i < len; ++i) total += weights[i];
    }
}
