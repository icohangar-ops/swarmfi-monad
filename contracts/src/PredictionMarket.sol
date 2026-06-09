// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ISwarmOracle} from "./interfaces/ISwarmOracle.sol";

/// @title PredictionMarket — parimutuel markets resolved by SwarmOracle consensus
contract PredictionMarket is Ownable, ReentrancyGuard {
    enum MarketStatus {
        Active,
        Resolved,
        Cancelled
    }

    struct Market {
        uint256 id;
        address creator;
        string question;
        string description;
        string outcomeA;
        string outcomeB;
        uint64 endTime;
        uint256 poolA;
        uint256 poolB;
        uint256 totalVolume;
        MarketStatus status;
        uint8 winningOutcome; // 0 = A, 1 = B, 255 = unset
        uint64 resolvedAt;
        bytes32 oracleAssetPair;
    }

    struct Position {
        uint256 marketId;
        uint8 outcome;
        uint256 stake;
        bool claimed;
    }

    ISwarmOracle public oracle;
    uint256 public marketCount;
    uint256 public feeRateBps = 200; // 2%

    mapping(uint256 => Market) public markets;
    mapping(uint256 => mapping(address => Position)) public positions;

    event MarketCreated(uint256 indexed marketId, string question, uint64 endTime);
    event PredictionSubmitted(uint256 indexed marketId, address indexed user, uint8 outcome, uint256 amount);
    event MarketResolved(uint256 indexed marketId, uint8 winningOutcome, uint256 oraclePrice);
    event WinningsClaimed(uint256 indexed marketId, address indexed user, uint256 amount);

    error MarketNotFound();
    error MarketClosed();
    error MarketNotResolved();
    error InvalidOutcome();
    error AlreadyClaimed();
    error NoPosition();
    error NothingToClaim();

    constructor(address admin, address oracle_) Ownable(admin) {
        oracle = ISwarmOracle(oracle_);
    }

    function createMarket(
        string calldata question,
        string calldata description,
        string calldata outcomeA,
        string calldata outcomeB,
        uint64 endTime,
        bytes32 oracleAssetPair
    ) external returns (uint256 marketId) {
        marketCount += 1;
        marketId = marketCount;

        markets[marketId] = Market({
            id: marketId,
            creator: msg.sender,
            question: question,
            description: description,
            outcomeA: outcomeA,
            outcomeB: outcomeB,
            endTime: endTime,
            poolA: 0,
            poolB: 0,
            totalVolume: 0,
            status: MarketStatus.Active,
            winningOutcome: 255,
            resolvedAt: 0,
            oracleAssetPair: oracleAssetPair
        });

        emit MarketCreated(marketId, question, endTime);
    }

    function submitPrediction(uint256 marketId, uint8 outcome) external payable nonReentrant {
        Market storage market = markets[marketId];
        if (market.id == 0) revert MarketNotFound();
        if (market.status != MarketStatus.Active) revert MarketClosed();
        if (block.timestamp >= market.endTime) revert MarketClosed();
        if (outcome > 1) revert InvalidOutcome();
        if (msg.value == 0) revert NothingToClaim();

        Position storage pos = positions[marketId][msg.sender];
        if (pos.stake == 0) {
            pos.marketId = marketId;
            pos.outcome = outcome;
            pos.stake = msg.value;
            pos.claimed = false;
        } else {
            if (pos.outcome != outcome) revert InvalidOutcome();
            pos.stake += msg.value;
        }

        if (outcome == 0) market.poolA += msg.value;
        else market.poolB += msg.value;
        market.totalVolume += msg.value;

        emit PredictionSubmitted(marketId, msg.sender, outcome, msg.value);
    }

    function resolveMarket(uint256 marketId, uint8 winningOutcome) external onlyOwner {
        Market storage market = markets[marketId];
        if (market.id == 0) revert MarketNotFound();
        if (market.status != MarketStatus.Active) revert MarketClosed();
        if (winningOutcome > 1) revert InvalidOutcome();

        (, uint64 computedAt, bool exists) = oracle.getLatestConsensus(market.oracleAssetPair);
        require(exists && computedAt > 0, "oracle missing");

        market.status = MarketStatus.Resolved;
        market.winningOutcome = winningOutcome;
        market.resolvedAt = uint64(block.timestamp);

        (uint256 oraclePrice,,) = oracle.getLatestConsensus(market.oracleAssetPair);
        emit MarketResolved(marketId, winningOutcome, oraclePrice);
    }

    function claimWinnings(uint256 marketId) external nonReentrant {
        Market storage market = markets[marketId];
        Position storage pos = positions[marketId][msg.sender];

        if (market.status != MarketStatus.Resolved) revert MarketNotResolved();
        if (pos.stake == 0) revert NoPosition();
        if (pos.claimed) revert AlreadyClaimed();
        if (pos.outcome != market.winningOutcome) revert NothingToClaim();

        uint256 winningPool = market.winningOutcome == 0 ? market.poolA : market.poolB;
        uint256 losingPool = market.winningOutcome == 0 ? market.poolB : market.poolA;
        uint256 totalPool = winningPool + losingPool;

        uint256 fee = (totalPool * feeRateBps) / 10_000;
        uint256 distributable = totalPool - fee;
        uint256 payout = (pos.stake * distributable) / winningPool;

        pos.claimed = true;
        payable(msg.sender).transfer(payout);
        emit WinningsClaimed(marketId, msg.sender, payout);
    }

    function getMarket(uint256 marketId) external view returns (Market memory) {
        return markets[marketId];
    }
}
