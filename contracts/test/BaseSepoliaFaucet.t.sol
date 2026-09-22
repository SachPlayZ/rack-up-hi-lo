// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {BaseSepoliaFaucet} from "contracts/BaseSepoliaFaucet.sol";

contract BaseSepoliaFaucetTest is Test {
    uint256 internal constant CLAIM_AMOUNT = 0.001 ether;

    address internal relayer = makeAddr("relayer");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal outsider = makeAddr("outsider");
    BaseSepoliaFaucet internal faucet;

    function setUp() public {
        faucet = new BaseSepoliaFaucet(address(this), relayer, CLAIM_AMOUNT);
        vm.deal(address(faucet), 1 ether);
    }

    function test_InitialConfiguration() external view {
        assertEq(faucet.owner(), address(this));
        assertEq(faucet.relayer(), relayer);
        assertEq(faucet.claimAmount(), CLAIM_AMOUNT);
        assertFalse(faucet.hasClaimed(alice));
    }

    function test_RevertWhen_ConstructorInputsAreInvalid() external {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new BaseSepoliaFaucet(address(0), relayer, CLAIM_AMOUNT);

        vm.expectRevert(BaseSepoliaFaucet.BaseSepoliaFaucet__ZeroAddress.selector);
        new BaseSepoliaFaucet(address(this), address(0), CLAIM_AMOUNT);

        vm.expectRevert(BaseSepoliaFaucet.BaseSepoliaFaucet__ZeroAmount.selector);
        new BaseSepoliaFaucet(address(this), relayer, 0);
    }

    function testFuzz_RelayerClaimsExactlyOnce(uint96 configuredAmount) external {
        configuredAmount = uint96(bound(configuredAmount, 1, 1 ether));
        faucet.setClaimAmount(configuredAmount);
        uint256 balanceBefore = alice.balance;

        vm.prank(relayer);
        faucet.claimFor(alice);
        assertEq(alice.balance - balanceBefore, configuredAmount);
        assertTrue(faucet.hasClaimed(alice));

        vm.prank(relayer);
        vm.expectRevert(BaseSepoliaFaucet.BaseSepoliaFaucet__AlreadyClaimed.selector);
        faucet.claimFor(alice);
    }

    function test_RevertWhen_CallerIsNotRelayer() external {
        vm.prank(outsider);
        vm.expectRevert(BaseSepoliaFaucet.BaseSepoliaFaucet__OnlyRelayer.selector);
        faucet.claimFor(alice);
    }

    function test_RevertWhen_RecipientIsZero() external {
        vm.prank(relayer);
        vm.expectRevert(BaseSepoliaFaucet.BaseSepoliaFaucet__ZeroAddress.selector);
        faucet.claimFor(address(0));
    }

    function test_RevertWhen_FaucetIsUnderfunded() external {
        BaseSepoliaFaucet emptyFaucet = new BaseSepoliaFaucet(address(this), relayer, CLAIM_AMOUNT);
        vm.prank(relayer);
        vm.expectRevert(BaseSepoliaFaucet.BaseSepoliaFaucet__InsufficientBalance.selector);
        emptyFaucet.claimFor(alice);
        assertFalse(emptyFaucet.hasClaimed(alice));
    }

    function test_OwnerUpdatesRelayerAndClaimAmount() external {
        faucet.setRelayer(outsider);
        faucet.setClaimAmount(2 * CLAIM_AMOUNT);
        assertEq(faucet.relayer(), outsider);
        assertEq(faucet.claimAmount(), 2 * CLAIM_AMOUNT);
    }

    function test_RevertWhen_NonOwnerUpdatesConfiguration() external {
        vm.startPrank(outsider);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, outsider));
        faucet.setRelayer(bob);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, outsider));
        faucet.setClaimAmount(2 * CLAIM_AMOUNT);
        vm.stopPrank();
    }

    function test_OwnerRecoversRequestedAmount() external {
        uint256 beforeBalance = bob.balance;
        faucet.recover(bob, 0.4 ether);
        assertEq(bob.balance - beforeBalance, 0.4 ether);
        assertEq(address(faucet).balance, 0.6 ether);
    }

    function test_RevertWhen_RecoveryInputsInvalid() external {
        vm.expectRevert(BaseSepoliaFaucet.BaseSepoliaFaucet__ZeroAddress.selector);
        faucet.recover(address(0), 1);
        vm.expectRevert(BaseSepoliaFaucet.BaseSepoliaFaucet__ZeroAmount.selector);
        faucet.recover(bob, 0);
        vm.expectRevert(BaseSepoliaFaucet.BaseSepoliaFaucet__InsufficientBalance.selector);
        faucet.recover(bob, 2 ether);
    }

    function test_ReceiveFundsFaucet() external {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        (bool success,) = address(faucet).call{value: 0.5 ether}("");
        assertTrue(success);
        assertEq(address(faucet).balance, 1.5 ether);
    }
}
