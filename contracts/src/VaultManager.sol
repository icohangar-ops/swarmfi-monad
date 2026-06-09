// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title VaultManager — share-based vaults with agent-triggered rebalancing
contract VaultManager is Ownable, ReentrancyGuard {
    enum Strategy {
        Conservative,
        Balanced,
        Aggressive
    }

    struct Vault {
        uint256 id;
        string name;
        Strategy strategy;
        address owner;
        uint256 totalValue;
        uint256 totalShares;
        uint8 riskScore;
        uint32 rebalanceCount;
        bool isActive;
        uint64 createdAt;
        uint64 lastRebalanceAt;
    }

    struct Deposit {
        uint256 amount;
        uint256 shares;
        uint64 depositedAt;
    }

    struct RebalanceRecord {
        uint256 id;
        uint256 vaultId;
        string fromAsset;
        string toAsset;
        uint256 amount;
        address triggeredBy;
        string reason;
        uint64 executedAt;
    }

    uint256 public vaultCount;
    uint256 public rebalanceCount;
    uint256 public feeRateBps = 50; // 0.5%

    mapping(uint256 => Vault) public vaults;
    mapping(uint256 => mapping(address => Deposit)) public deposits;
    mapping(address => bool) public whitelistedAgents;
    mapping(uint256 => RebalanceRecord) public rebalances;

    event VaultCreated(uint256 indexed vaultId, string name, Strategy strategy);
    event Deposited(uint256 indexed vaultId, address indexed user, uint256 amount, uint256 shares);
    event Withdrawn(uint256 indexed vaultId, address indexed user, uint256 amount, uint256 shares);
    event Rebalanced(uint256 indexed vaultId, address indexed agent, string fromAsset, string toAsset, uint256 amount);
    event AgentWhitelisted(address indexed agent, bool active);

    error VaultNotFound();
    error VaultInactive();
    error NotWhitelisted();
    error InsufficientShares();
    error ZeroAmount();

    constructor(address admin) Ownable(admin) {}

    function setWhitelistedAgent(address agent, bool active) external onlyOwner {
        whitelistedAgents[agent] = active;
        emit AgentWhitelisted(agent, active);
    }

    function createVault(string calldata name, Strategy strategy) external returns (uint256 vaultId) {
        vaultCount += 1;
        vaultId = vaultCount;

        vaults[vaultId] = Vault({
            id: vaultId,
            name: name,
            strategy: strategy,
            owner: msg.sender,
            totalValue: 0,
            totalShares: 0,
            riskScore: _riskScore(strategy),
            rebalanceCount: 0,
            isActive: true,
            createdAt: uint64(block.timestamp),
            lastRebalanceAt: 0
        });

        emit VaultCreated(vaultId, name, strategy);
    }

    function deposit(uint256 vaultId) external payable nonReentrant {
        if (msg.value == 0) revert ZeroAmount();
        Vault storage vault = vaults[vaultId];
        if (vault.id == 0) revert VaultNotFound();
        if (!vault.isActive) revert VaultInactive();

        uint256 shares;
        if (vault.totalShares == 0) {
            shares = msg.value;
        } else {
            shares = (msg.value * vault.totalShares) / vault.totalValue;
        }

        Deposit storage dep = deposits[vaultId][msg.sender];
        dep.amount += msg.value;
        dep.shares += shares;
        dep.depositedAt = uint64(block.timestamp);

        vault.totalValue += msg.value;
        vault.totalShares += shares;

        emit Deposited(vaultId, msg.sender, msg.value, shares);
    }

    function withdraw(uint256 vaultId, uint256 shareAmount) external nonReentrant {
        if (shareAmount == 0) revert ZeroAmount();
        Vault storage vault = vaults[vaultId];
        Deposit storage dep = deposits[vaultId][msg.sender];

        if (vault.id == 0) revert VaultNotFound();
        if (dep.shares < shareAmount) revert InsufficientShares();

        uint256 payout = (shareAmount * vault.totalValue) / vault.totalShares;
        uint256 fee = (payout * feeRateBps) / 10_000;
        uint256 net = payout - fee;

        dep.shares -= shareAmount;
        dep.amount = dep.shares == 0 ? 0 : dep.amount - payout;
        vault.totalShares -= shareAmount;
        vault.totalValue -= payout;

        payable(msg.sender).transfer(net);
        if (fee > 0) payable(owner()).transfer(fee);

        emit Withdrawn(vaultId, msg.sender, net, shareAmount);
    }

    function rebalance(
        uint256 vaultId,
        string calldata fromAsset,
        string calldata toAsset,
        uint256 amount,
        string calldata reason
    ) external {
        if (!whitelistedAgents[msg.sender]) revert NotWhitelisted();
        Vault storage vault = vaults[vaultId];
        if (vault.id == 0) revert VaultNotFound();
        if (!vault.isActive) revert VaultInactive();
        if (amount == 0) revert ZeroAmount();

        vault.rebalanceCount += 1;
        vault.lastRebalanceAt = uint64(block.timestamp);
        rebalanceCount += 1;

        rebalances[rebalanceCount] = RebalanceRecord({
            id: rebalanceCount,
            vaultId: vaultId,
            fromAsset: fromAsset,
            toAsset: toAsset,
            amount: amount,
            triggeredBy: msg.sender,
            reason: reason,
            executedAt: uint64(block.timestamp)
        });

        emit Rebalanced(vaultId, msg.sender, fromAsset, toAsset, amount);
    }

    function shareValue(uint256 vaultId) external view returns (uint256) {
        Vault storage vault = vaults[vaultId];
        if (vault.totalShares == 0) return 1 ether;
        return vault.totalValue / vault.totalShares;
    }

    function _riskScore(Strategy strategy) internal pure returns (uint8) {
        if (strategy == Strategy.Conservative) return 1;
        if (strategy == Strategy.Balanced) return 5;
        return 9;
    }
}
