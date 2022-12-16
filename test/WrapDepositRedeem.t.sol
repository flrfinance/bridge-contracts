// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { WrapTest } from "./Wrap.t.sol";
import { IWrap } from "../src/interfaces/IWrap.sol";
import {
    WrapDepositRedeemHarness
} from "../src/test/WrapDepositRedeemHarness.sol";
import { WrapHarness } from "../src/test/WrapHarness.sol";
import { Multisig } from "../src/libraries/Multisig.sol";
import { TestERC20 } from "../src/test/TestERC20.sol";

contract WrapDepositRedeemTest is WrapTest {
    uint8 constant validatorsFeeBPS = 100;
    uint8 constant protocolFeeBPS = 0;

    WrapDepositRedeemHarness wdr;

    uint256 testTokenInitialSupply = UINT256_MAX;

    function _addToken() internal override {
        IERC20 newToken = new TestERC20(
            testTokenName,
            testTokenSymbol,
            testTokenInitialSupply
        );

        token = address(newToken);
        mirrorToken = _generateMirrorToken();
        vm.prank(admin);
        wdr.addToken(token, mirrorToken, tokenInfo);
    }

    function _mintTokens(address to, uint256 amount) internal override {
        IERC20(token).transfer(to, amount);
    }

    constructor() {
        config = Multisig.Config(
            firstCommitteeAcceptanceQuorum,
            secondCommitteeAcceptanceQuorum
        );

        vm.prank(admin);
        wdr = new WrapDepositRedeemHarness(config, validatorsFeeBPS);
        wrap = WrapHarness(wdr);
    }

    function testConstructorValidatorFeeBPS() public {
        assertEq(wdr.validatorsFeeBPS(), validatorsFeeBPS);
    }

    function _testAccumulatedValidatorsFees(uint256 validatorsFees) internal {
        vm.mockCall(
            token,
            abi.encodeWithSelector(IERC20.balanceOf.selector),
            abi.encode(validatorsFees)
        );
        assertEq(wdr.accumalatedValidatorsFees(token), validatorsFees);
    }

    function testAccumulatedValidatorsFees() public override {
        _testAccumulatedValidatorsFees(0);
        _testAccumulatedValidatorsFees(100);
        _testAccumulatedValidatorsFees(1337);
        _testAccumulatedValidatorsFees(31337);
        _testAccumulatedValidatorsFees(432e20);
    }

    function testAccumulatedValidatorsFees(uint256 validatorsFees) public {
        _testAccumulatedValidatorsFees(validatorsFees);
    }

    function _testOnDeposit(uint256 userInitialBalance, uint256 amountToDeposit)
        internal
        override
        withToken
        withMintedTokens(user, userInitialBalance)
    {
        vm.startPrank(user);
        IERC20(token).approve(address(wrap), amountToDeposit);
        vm.expectEmit(true, true, true, true, token);
        emit Transfer(user, address(wrap), amountToDeposit);
        assertEq(wrap.exposed_onDeposit(token, amountToDeposit), 0);
        vm.stopPrank();
        assertEq(
            IERC20(token).balanceOf(user),
            userInitialBalance - amountToDeposit
        );
        assertEq(IERC20(token).balanceOf(address(wrap)), amountToDeposit);
    }

    function _testDepositFees(uint256 amount) internal override {
        assertEq(wrap.exposed_depositFees(amount), 0);
    }

    function _testOnExecute(uint256 amount)
        internal
        override
        withToken
        withMintedTokens(address(wrap), amount)
    {
        uint256 initialRecipientBalance = IERC20(token).balanceOf(user);
        uint256 fee = wrap.exposed_calculateFee(amount, validatorsFeeBPS);
        vm.expectEmit(true, true, true, true, token);
        emit Transfer(address(wrap), user, amount - fee);
        assertEq(wrap.exposed_onExecute(token, amount, user), fee);
        assertEq(
            IERC20(token).balanceOf(user),
            initialRecipientBalance + (amount - fee)
        );
    }

    function _testExecuteFees(uint256 amount) internal override {
        assertEq(
            wrap.exposed_executeFees(amount),
            wrap.exposed_calculateFee(amount, validatorsFeeBPS)
        );
    }

    function testConfigureFees() public {
        uint16 newValidatorsFeeBPS = validatorsFeeBPS / 2;
        vm.prank(admin);
        wdr.configureFees(newValidatorsFeeBPS);
        assertEq(wdr.validatorsFeeBPS(), newValidatorsFeeBPS);
    }

    function testConfigureFees(uint16 newValidatorsFeeBPS) public {
        vm.assume(newValidatorsFeeBPS < wdr.exposed_maxFeeBPS());
        vm.prank(admin);
        wdr.configureFees(newValidatorsFeeBPS);
        assertEq(wdr.validatorsFeeBPS(), newValidatorsFeeBPS);
    }

    function testConfigureFeesCanBeSetToZero() public {
        vm.prank(admin);
        wdr.configureFees(0);
        assertEq(wdr.validatorsFeeBPS(), 0);
    }

    function testConfigureFeesRevertsIfFeeExceedsMax() public {
        uint16 maxFeeBPS = wdr.exposed_maxFeeBPS();
        vm.prank(admin);
        vm.expectRevert(IWrap.FeeExceedsMaxFee.selector);
        wdr.configureFees(maxFeeBPS + 1);
    }

    function testConfigureFeesRevertsIfCallerIsNotAdmin() public {
        vm.prank(user);
        _expectMissingRoleRevert(user, DEFAULT_ADMIN_ROLE);
        wdr.configureFees(validatorsFeeBPS / 2);
    }

    function testAddToken() public {
        token = address(
            new TestERC20(
                testTokenName,
                testTokenSymbol,
                testTokenInitialSupply
            )
        );

        mirrorToken = _generateMirrorToken();
        vm.prank(admin);
        wdr.addToken(token, mirrorToken, tokenInfo);
        _assertCorrectAddTokenState();
    }

    function testAddTokenRevertsIfCallerIsNotAdmin() public {
        token = address(
            new TestERC20(
                testTokenName,
                testTokenSymbol,
                testTokenInitialSupply
            )
        );

        mirrorToken = _generateMirrorToken();
        vm.prank(user);
        _expectMissingRoleRevert(user, DEFAULT_ADMIN_ROLE);
        wdr.addToken(token, mirrorToken, tokenInfo);
    }

    function _claimValidatorFees() internal override {
        wdr.claimValidatorFees();
    }

    function _accumulatedValidatorsFees()
        internal
        view
        override
        returns (uint256)
    {
        uint256 contractBalance = IERC20(token).balanceOf(address(wrap));
        return contractBalance;
    }

    function _expectDepositEvents(
        uint256 depositIndex,
        address token,
        uint256 amount,
        uint256 fee,
        address recipient
    ) internal override {
        vm.expectEmit(true, true, true, true, token);
        emit Transfer(recipient, address(wrap), amount);
        vm.expectEmit(true, true, true, true, address(wrap));
        emit Deposit(depositIndex, token, amount - fee, recipient, fee);
    }

    function _expectDepositFinalContractBalance(
        uint256 initialContractBalance,
        uint256 amount
    ) internal override {
        assertEq(
            IERC20(token).balanceOf(address(wrap)),
            initialContractBalance + amount
        );
    }

    function _expectApproveExecuteFinalEvents(
        uint256 id,
        address token,
        uint256 amount,
        address recipient
    ) internal override {
        uint256 fee = wrap.exposed_executeFees(amount);
        vm.expectEmit(true, true, true, true, token);
        emit Transfer(address(wrap), recipient, amount - fee);
        vm.expectEmit(true, true, true, true, address(wrap));
        emit Executed(id, token, amount - fee, recipient, fee);
    }

    function _expectApproveExecuteFinalContractBalance(
        uint256 initialContractBalance,
        uint256 amount,
        uint256 fee
    ) internal override {
        assertEq(
            IERC20(token).balanceOf(address(wrap)),
            initialContractBalance - amount + fee
        );
    }
}
