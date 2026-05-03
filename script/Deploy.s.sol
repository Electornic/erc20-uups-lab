// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {LabTokenV1} from "../src/LabTokenV1.sol";

contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);

        uint256 initialSupply = 1_000_000 ether;

        vm.startBroadcast(pk);

        address proxy = Upgrades.deployUUPSProxy(
            "LabTokenV1.sol", abi.encodeCall(LabTokenV1.initialize, (deployer, initialSupply))
        );

        vm.stopBroadcast();

        address implementation = Upgrades.getImplementationAddress(proxy);

        console.log("=========================================");
        console.log("LabTokenV1 deployed");
        console.log("=========================================");
        console.log("Proxy (use this address):", proxy);
        console.log("Implementation:           ", implementation);
        console.log("Owner / Initial holder:   ", deployer);
        console.log("Initial supply (LAB):     ", initialSupply / 1e18);
    }
}
