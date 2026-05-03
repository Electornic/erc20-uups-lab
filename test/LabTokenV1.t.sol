// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {LabTokenV1} from "../src/LabTokenV1.sol";

contract LabTokenV1Test is Test {
    LabTokenV1 token;
    address proxy;
    address owner = address(0xA11CE);
    address user = address(0xB0B);

    uint256 constant INITIAL_SUPPLY = 1_000_000 ether;

    function setUp() public {
        proxy =
            Upgrades.deployUUPSProxy("LabTokenV1.sol", abi.encodeCall(LabTokenV1.initialize, (owner, INITIAL_SUPPLY)));
        token = LabTokenV1(proxy);
    }

    function test_Metadata() public view {
        assertEq(token.name(), "Lab Token");
        assertEq(token.symbol(), "LAB");
        assertEq(token.decimals(), 18);
    }

    function test_InitialMintToOwner() public view {
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.owner(), owner);
    }

    function test_OwnerCanMint() public {
        vm.prank(owner);
        token.mint(user, 100 ether);
        assertEq(token.balanceOf(user), 100 ether);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + 100 ether);
    }

    function test_NonOwnerCannotMint() public {
        vm.prank(user);
        vm.expectRevert();
        token.mint(user, 100 ether);
    }

    function test_Transfer() public {
        vm.prank(owner);
        token.transfer(user, 500 ether);
        assertEq(token.balanceOf(user), 500 ether);
    }

    function test_NonOwnerCannotUpgrade() public {
        LabTokenV1 newImpl = new LabTokenV1();
        vm.prank(user);
        vm.expectRevert();
        token.upgradeToAndCall(address(newImpl), "");
    }

    function test_ImplementationIsLocked() public {
        address impl = Upgrades.getImplementationAddress(proxy);
        vm.expectRevert();
        LabTokenV1(impl).initialize(owner, 0);
    }
}
