// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {ReputationRegistry} from "../src/ReputationRegistry.sol";
import {SwarmOracle} from "../src/SwarmOracle.sol";
import {PredictionMarket} from "../src/PredictionMarket.sol";
import {VaultManager} from "../src/VaultManager.sol";

contract DeploySwarmFi is Script {
    function run() external {
        // Signs with --private-key on CLI, or PRIVATE_KEY in .env via --sig "run()" with env loaded
        uint256 deployerKey = vm.envOr("PRIVATE_KEY", uint256(0));
        if (deployerKey != 0) {
            vm.startBroadcast(deployerKey);
        } else {
            vm.startBroadcast();
        }
        address deployer = msg.sender;

        ReputationRegistry reputation = new ReputationRegistry(deployer);
        SwarmOracle oracle = new SwarmOracle(deployer, address(reputation));
        PredictionMarket market = new PredictionMarket(deployer, address(oracle));
        VaultManager vaults = new VaultManager(deployer);

        reputation.authorizeUpdater(address(oracle), true);

        vm.stopBroadcast();

        console2.log("ReputationRegistry", address(reputation));
        console2.log("SwarmOracle", address(oracle));
        console2.log("PredictionMarket", address(market));
        console2.log("VaultManager", address(vaults));
    }
}
