// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ReputationRegistry} from "../src/ReputationRegistry.sol";
import {SwarmOracle} from "../src/SwarmOracle.sol";
import {PredictionMarket} from "../src/PredictionMarket.sol";
import {VaultManager} from "../src/VaultManager.sol";

contract SwarmFiTest is Test {
    ReputationRegistry reputation;
    SwarmOracle oracle;
    PredictionMarket market;
    VaultManager vaults;

    address admin = address(0xA11CE);
    address agent1 = address(0xB01);
    address agent2 = address(0xB02);
    address agent3 = address(0xB03);
    address user = makeAddr("user");

    bytes32 constant BTC_USD = keccak256("BTC/USD");

    function setUp() public {
        vm.deal(admin, 100 ether);
        vm.deal(agent1, 10 ether);
        vm.deal(agent2, 10 ether);
        vm.deal(agent3, 10 ether);
        vm.deal(user, 10 ether);

        vm.prank(admin);
        reputation = new ReputationRegistry(admin);

        vm.prank(admin);
        oracle = new SwarmOracle(admin, address(reputation));

        vm.prank(admin);
        market = new PredictionMarket(admin, address(oracle));

        vm.prank(admin);
        vaults = new VaultManager(admin);

        vm.prank(admin);
        reputation.authorizeUpdater(address(oracle), true);

        vm.prank(admin);
        reputation.registerAgent(agent1);
        vm.prank(admin);
        reputation.registerAgent(agent2);
        vm.prank(admin);
        reputation.registerAgent(agent3);
    }

    function testAgentRegistrationAndConsensus() public {
        vm.prank(agent1);
        oracle.registerAgent{value: 0.1 ether}("Alpha", SwarmOracle.AgentType.Price);

        vm.prank(agent2);
        oracle.registerAgent{value: 0.1 ether}("Beta", SwarmOracle.AgentType.Price);

        vm.prank(agent3);
        oracle.registerAgent{value: 0.1 ether}("Gamma", SwarmOracle.AgentType.Price);

        vm.prank(agent1);
        oracle.submitPrice(BTC_USD, 100_000e8, 90);
        vm.prank(agent2);
        oracle.submitPrice(BTC_USD, 100_100e8, 85);
        vm.prank(agent3);
        oracle.submitPrice(BTC_USD, 99_900e8, 88);

        oracle.runConsensus(BTC_USD);

        (uint256 price, uint64 computedAt, bool exists) = oracle.getLatestConsensus(BTC_USD);
        assertTrue(exists);
        assertGt(price, 0);
        assertGt(computedAt, 0);
    }

    function testPredictionMarketLifecycle() public {
        _seedConsensus();

        vm.prank(admin);
        uint256 marketId = market.createMarket(
            "Will BTC close above $100k?",
            "Resolves using oracle consensus",
            "Yes",
            "No",
            uint64(block.timestamp + 1 days),
            BTC_USD
        );

        vm.prank(user);
        market.submitPrediction{value: 1 ether}(marketId, 0);

        vm.prank(admin);
        market.resolveMarket(marketId, 0);

        uint256 before = user.balance;
        vm.prank(user);
        market.claimWinnings(marketId);
        // 2% protocol fee on the 1 MON pool
        uint256 expectedPayout = 1 ether - ((1 ether * 200) / 10_000);
        assertEq(user.balance, before + expectedPayout);
    }

    function testVaultDepositWithdraw() public {
        vm.prank(admin);
        uint256 vaultId = vaults.createVault("Balanced MON", VaultManager.Strategy.Balanced);

        vm.prank(user);
        vaults.deposit{value: 2 ether}(vaultId);

        (uint256 amount, uint256 shares,) = vaults.deposits(vaultId, user);
        assertGt(amount, 0);
        assertGt(shares, 0);

        vm.prank(user);
        vaults.withdraw(vaultId, shares / 2);
    }

    function _seedConsensus() internal {
        vm.prank(agent1);
        oracle.registerAgent{value: 0.1 ether}("A1", SwarmOracle.AgentType.Price);
        vm.prank(agent2);
        oracle.registerAgent{value: 0.1 ether}("A2", SwarmOracle.AgentType.Price);
        vm.prank(agent3);
        oracle.registerAgent{value: 0.1 ether}("A3", SwarmOracle.AgentType.Price);

        vm.prank(agent1);
        oracle.submitPrice(BTC_USD, 100_000e8, 90);
        vm.prank(agent2);
        oracle.submitPrice(BTC_USD, 100_000e8, 90);
        vm.prank(agent3);
        oracle.submitPrice(BTC_USD, 100_000e8, 90);
        oracle.runConsensus(BTC_USD);
    }
}
