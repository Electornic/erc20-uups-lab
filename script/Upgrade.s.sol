// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {LabTokenV2} from "../src/LabTokenV2.sol";

contract Upgrade is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        address proxyAddr = vm.envAddress("PROXY_ADDRESS");

        uint256 maxSupply = 21_000_000 ether;

        vm.startBroadcast(pk);

        Upgrades.upgradeProxy(
            proxyAddr, "LabTokenV2.sol", abi.encodeCall(LabTokenV2.initializeV2, (maxSupply, deployer))
        );

        vm.stopBroadcast();

        address newImpl = Upgrades.getImplementationAddress(proxyAddr);

        console.log("=========================================");
        console.log("Upgraded to LabTokenV2");
        console.log("=========================================");
        console.log("Proxy (unchanged):     ", proxyAddr);
        console.log("New Implementation:    ", newImpl);
        console.log("Admin (all roles):     ", deployer);
        console.log("Max Supply (LAB):      ", maxSupply / 1e18);
    }
}
