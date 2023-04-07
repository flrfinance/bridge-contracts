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
    uint16 constant protocolFeeBPS = 0;

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
        vm.prank(weakAdmin);
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

        validatorFeeBPS = 100;

        vm.prank(admin);
        wdr = new WrapDepositRedeemHarness(config, validatorFeeBPS);
        wrap = WrapHarness(wdr);

        assertTrue(wrap.hasRole(wrap.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(wrap.hasRole(wrap.WEAK_ADMIN_ROLE(), admin));

        vm.prank(admin);
        wrap.grantRole(WEAK_ADMIN_ROLE, weakAdmin);
        vm.prank(admin);
        wrap.renounceRole(WEAK_ADMIN_ROLE, admin);
    }

    function testConstructorValidatorFeeBPS() public {
        assertEq(wrap.validatorFeeBPS(), validatorFeeBPS);
    }

    function _testOnDeposit(
        uint256 userInitialBalance,
        uint256 amountToDeposit
    )
        internal
        virtual
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

    function _onExecuteFee(
        uint256 amount
    ) internal virtual override returns (uint256, uint256) {
        uint256 validatorFee = wrap.exposed_calculateFee(
            amount,
            validatorFeeBPS
        );
        return (validatorFee, validatorFee);
    }

    function _onExecutePerformExternalAction(
        address,
        uint256,
        address,
        uint256
    ) internal virtual override {}

    function _testOnExecute(
        uint256 amount
    )
        internal
        virtual
        override
        withToken
        withMintedTokens(address(wrap), amount)
    {
        uint256 initialRecipientBalance = IERC20(token).balanceOf(user);
        uint256 expectedFee = wrap.exposed_calculateFee(
            amount,
            validatorFeeBPS
        );
        uint256 expectedValidatorFee = expectedFee;
        vm.expectEmit(true, true, true, true, token);
        emit Transfer(address(wrap), user, amount - expectedFee);
        (uint256 actualFee, uint256 actualValidatorFee) = wrap
            .exposed_onExecute(token, amount, user);
        assertEq(actualFee, expectedFee);
        assertEq(actualValidatorFee, expectedValidatorFee);
        assertEq(
            IERC20(token).balanceOf(user),
            initialRecipientBalance + (amount - expectedFee)
        );
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
        vm.prank(weakAdmin);
        wdr.addToken(token, mirrorToken, tokenInfo);
        _assertCorrectAddTokenState();
    }

    function testAddTokenRevertsIfCallerIsNotWeakAdmin() public {
        token = address(
            new TestERC20(
                testTokenName,
                testTokenSymbol,
                testTokenInitialSupply
            )
        );

        mirrorToken = _generateMirrorToken();
        vm.prank(user);
        _expectMissingRoleRevert(user, WEAK_ADMIN_ROLE);
        wdr.addToken(token, mirrorToken, tokenInfo);
    }

    function _expectDepositEvents(
        uint256 depositIndex,
        address token,
        uint256 amount,
        uint256 fee,
        address recipient
    ) internal override {
        vm.expectEmit(true, true, true, true, token);
        emit Transfer(recipient, _custodian(), amount);
        vm.expectEmit(true, true, true, true, address(wrap));
        emit Deposit(depositIndex, token, amount - fee, recipient, fee);
    }

    function _custodian() internal view virtual override returns (address) {
        return address(wrap);
    }

    function _expectDepositFinalCustodianBalance(
        uint256 initialCustodianBalance,
        uint256 amount
    ) internal override {
        assertEq(
            IERC20(token).balanceOf(_custodian()),
            initialCustodianBalance + amount
        );
    }

    function _expectApproveExecuteFinalEvents(
        uint256 id,
        address token,
        uint256 amount,
        address recipient,
        uint256 fee
    ) internal virtual override {
        vm.expectEmit(true, true, true, true, token);
        emit Transfer(address(wrap), recipient, amount - fee);
        vm.expectEmit(true, true, true, true, address(wrap));
        emit Executed(id, mirrorToken, token, amount - fee, recipient, fee);
    }

    function _expectApproveExecuteFinalCustodianBalance(
        uint256 initialCustodianBalance,
        uint256 amount,
        uint256 fee
    ) internal override {
        assertEq(
            IERC20(token).balanceOf(_custodian()),
            initialCustodianBalance - amount + fee
        );
    }
}
