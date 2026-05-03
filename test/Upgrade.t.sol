// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {LabTokenV1} from "../src/LabTokenV1.sol";
import {LabTokenV2} from "../src/LabTokenV2.sol";

contract UpgradeTest is Test {
    address proxy;
    address owner = address(0xA11CE);
    address user = address(0xB0B);
    address other = address(0xCAFE);

    uint256 constant V1_INITIAL_SUPPLY = 1_000_000 ether;
    uint256 constant MAX_SUPPLY = 21_000_000 ether;

    function setUp() public {
        // Deploy V1
        proxy = Upgrades.deployUUPSProxy(
            "LabTokenV1.sol", abi.encodeCall(LabTokenV1.initialize, (owner, V1_INITIAL_SUPPLY))
        );

        // Mint some more so we can verify state preservation
        vm.prank(owner);
        LabTokenV1(proxy).mint(user, 500 ether);
    }

    function _upgradeToV2() internal {
        vm.startPrank(owner);
        Upgrades.upgradeProxy(proxy, "LabTokenV2.sol", abi.encodeCall(LabTokenV2.initializeV2, (MAX_SUPPLY, owner)));
        vm.stopPrank();
    }

    // ───────── State Preservation ─────────

    function test_StatePreserved_AfterUpgrade() public {
        uint256 supplyBefore = LabTokenV1(proxy).totalSupply();
        uint256 ownerBalBefore = LabTokenV1(proxy).balanceOf(owner);
        uint256 userBalBefore = LabTokenV1(proxy).balanceOf(user);

        _upgradeToV2();

        LabTokenV2 v2 = LabTokenV2(proxy);
        assertEq(v2.totalSupply(), supplyBefore, "totalSupply changed");
        assertEq(v2.balanceOf(owner), ownerBalBefore, "owner balance changed");
        assertEq(v2.balanceOf(user), userBalBefore, "user balance changed");
        assertEq(v2.name(), "Lab Token");
        assertEq(v2.symbol(), "LAB");
    }

    function test_NewState_Initialized() public {
        _upgradeToV2();

        LabTokenV2 v2 = LabTokenV2(proxy);
        assertEq(v2.maxSupply(), MAX_SUPPLY);
        assertTrue(v2.hasRole(v2.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(v2.hasRole(v2.MINTER_ROLE(), owner));
        assertTrue(v2.hasRole(v2.PAUSER_ROLE(), owner));
        assertTrue(v2.hasRole(v2.UPGRADER_ROLE(), owner));
    }

    function test_CannotReinitialize() public {
        _upgradeToV2();
        LabTokenV2 v2 = LabTokenV2(proxy);

        vm.expectRevert();
        v2.initializeV2(MAX_SUPPLY, other);
    }

    // ───────── AccessControl ─────────

    function test_RoleBasedMint() public {
        _upgradeToV2();
        LabTokenV2 v2 = LabTokenV2(proxy);

        vm.prank(owner);
        v2.mint(user, 100 ether);
        assertEq(v2.balanceOf(user), 600 ether);
    }

    function test_NonMinterCannotMint() public {
        _upgradeToV2();
        LabTokenV2 v2 = LabTokenV2(proxy);

        vm.prank(other);
        vm.expectRevert();
        v2.mint(other, 100 ether);
    }

    function test_AdminCanGrantMinterRole() public {
        _upgradeToV2();
        LabTokenV2 v2 = LabTokenV2(proxy);

        bytes32 minterRole = v2.MINTER_ROLE();
        vm.prank(owner);
        v2.grantRole(minterRole, other);

        vm.prank(other);
        v2.mint(other, 100 ether);
        assertEq(v2.balanceOf(other), 100 ether);
    }

    // ───────── Cap (21M) ─────────

    function test_MintRespectsCap() public {
        _upgradeToV2();
        LabTokenV2 v2 = LabTokenV2(proxy);

        uint256 remaining = MAX_SUPPLY - v2.totalSupply();
        vm.prank(owner);
        v2.mint(user, remaining);
        assertEq(v2.totalSupply(), MAX_SUPPLY);
    }

    function test_MintRevertsAboveCap() public {
        _upgradeToV2();
        LabTokenV2 v2 = LabTokenV2(proxy);

        uint256 remaining = MAX_SUPPLY - v2.totalSupply();
        vm.prank(owner);
        vm.expectRevert();
        v2.mint(user, remaining + 1);
    }

    // ───────── Burnable ─────────

    function test_Burn() public {
        _upgradeToV2();
        LabTokenV2 v2 = LabTokenV2(proxy);

        uint256 supplyBefore = v2.totalSupply();
        vm.prank(user);
        v2.burn(100 ether);

        assertEq(v2.balanceOf(user), 400 ether);
        assertEq(v2.totalSupply(), supplyBefore - 100 ether);
    }

    function test_BurnFromAfterApprove() public {
        _upgradeToV2();
        LabTokenV2 v2 = LabTokenV2(proxy);

        vm.prank(user);
        v2.approve(other, 100 ether);

        vm.prank(other);
        v2.burnFrom(user, 100 ether);

        assertEq(v2.balanceOf(user), 400 ether);
    }

    // ───────── Pausable ─────────

    function test_Pause_BlocksTransfer() public {
        _upgradeToV2();
        LabTokenV2 v2 = LabTokenV2(proxy);

        vm.prank(owner);
        v2.pause();

        vm.prank(owner);
        vm.expectRevert();
        v2.transfer(user, 1 ether);
    }

    function test_Pause_BlocksMint() public {
        _upgradeToV2();
        LabTokenV2 v2 = LabTokenV2(proxy);

        vm.prank(owner);
        v2.pause();

        vm.prank(owner);
        vm.expectRevert();
        v2.mint(user, 1 ether);
    }

    function test_Unpause_RestoresTransfer() public {
        _upgradeToV2();
        LabTokenV2 v2 = LabTokenV2(proxy);

        vm.prank(owner);
        v2.pause();
        vm.prank(owner);
        v2.unpause();

        vm.prank(owner);
        v2.transfer(user, 1 ether);
        assertEq(v2.balanceOf(user), 501 ether);
    }

    function test_NonPauserCannotPause() public {
        _upgradeToV2();
        LabTokenV2 v2 = LabTokenV2(proxy);

        vm.prank(other);
        vm.expectRevert();
        v2.pause();
    }

    // ───────── Votes ─────────

    function test_VotingPowerZeroBeforeDelegate() public {
        _upgradeToV2();
        LabTokenV2 v2 = LabTokenV2(proxy);

        // user has 500 LAB but hasn't delegated → 0 votes
        assertEq(v2.getVotes(user), 0);
    }

    function test_DelegateGrantsVotingPower() public {
        _upgradeToV2();
        LabTokenV2 v2 = LabTokenV2(proxy);

        vm.prank(user);
        v2.delegate(user); // self-delegate

        assertEq(v2.getVotes(user), 500 ether);
    }

    function test_DelegateToOther() public {
        _upgradeToV2();
        LabTokenV2 v2 = LabTokenV2(proxy);

        vm.prank(user);
        v2.delegate(other);

        assertEq(v2.getVotes(user), 0);
        assertEq(v2.getVotes(other), 500 ether);
    }

    function test_VotingPower_TracksTransfer() public {
        _upgradeToV2();
        LabTokenV2 v2 = LabTokenV2(proxy);

        vm.prank(owner);
        v2.delegate(owner);
        vm.prank(user);
        v2.delegate(user);

        uint256 ownerVotesBefore = v2.getVotes(owner);
        vm.prank(owner);
        v2.transfer(user, 1000 ether);

        assertEq(v2.getVotes(owner), ownerVotesBefore - 1000 ether);
        assertEq(v2.getVotes(user), 500 ether + 1000 ether);
    }

    // ───────── Upgrade authorization ─────────

    function test_NonUpgraderCannotUpgrade() public {
        _upgradeToV2();
        LabTokenV2 v2 = LabTokenV2(proxy);

        LabTokenV2 newImpl = new LabTokenV2();
        vm.prank(other);
        vm.expectRevert();
        v2.upgradeToAndCall(address(newImpl), "");
    }
}
