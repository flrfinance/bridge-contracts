// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { WrapTest } from "./Wrap.t.sol";
import { IWrap } from "../src/interfaces/IWrap.sol";
import { IERC20MintBurn } from "../src/interfaces/IERC20MintBurn.sol";
import { WrapMintBurnHarness } from "../src/test/WrapMintBurnHarness.sol";
import { WrapHarness } from "../src/test/WrapHarness.sol";
import { Multisig } from "../src/libraries/Multisig.sol";

contract WrapMintBurnTest is WrapTest {
    uint16 constant protocolFeeBPS = 100;
    uint16 constant validatorsFeeBPS = 100;

    WrapMintBurnHarness wmb;

    uint8 mirrorTokenDecimals = 18;

    function _addToken() internal override {
        mirrorToken = _generateMirrorToken();
        vm.prank(admin);
        token = wmb.createAddToken(
            testTokenName,
            testTokenSymbol,
            mirrorToken,
            mirrorTokenDecimals,
            tokenInfo
        );
    }

    function _mintTokens(address account, uint256 amount) internal override {
        vm.prank(address(wrap));
        IERC20MintBurn(token).mint(account, amount);
    }

    constructor() {
        config = Multisig.Config(
            firstCommitteeAcceptanceQuorum,
            secondCommitteeAcceptanceQuorum
        );

        vm.prank(admin);
        wmb = new WrapMintBurnHarness(config, protocolFeeBPS, validatorsFeeBPS);
        wrap = WrapHarness(wmb);
    }

    function testConstructorProtocolFeeBPS() public {
        assertEq(wmb.protocolFeeBPS(), protocolFeeBPS);
    }

    function testConstructorValidatorFeeBPS() public {
        assertEq(wmb.validatorsFeeBPS(), validatorsFeeBPS);
    }

    function _testAccumulatedValidatorsFees(uint256 validatorsFees) internal {
        // TODO: Perform some actions to increase protocol fees
        uint256 accumalatedProtocolFees = wmb.accumalatedProtocolFees(token);
        vm.mockCall(
            token,
            abi.encodeWithSelector(IERC20.balanceOf.selector),
            abi.encode(validatorsFees)
        );
        assertEq(
            wmb.accumalatedValidatorsFees(token),
            validatorsFees - accumalatedProtocolFees
        );
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
        uint256 initialAccumulatedProtocolFees = wmb.accumalatedProtocolFees(
            token
        );
        uint256 fee = wrap.exposed_depositFees(amountToDeposit);
        vm.startPrank(user);
        IERC20(token).approve(address(wrap), amountToDeposit);
        vm.expectEmit(true, true, true, true, token);
        emit Transfer(user, address(0), amountToDeposit - fee);
        vm.expectEmit(true, true, true, true, token);
        emit Transfer(user, address(wrap), fee);
        assertEq(wrap.exposed_onDeposit(token, amountToDeposit), fee);
        vm.stopPrank();
        assertEq(
            wmb.accumalatedProtocolFees(token),
            initialAccumulatedProtocolFees + fee
        );
        assertEq(
            IERC20(token).balanceOf(user),
            userInitialBalance - amountToDeposit
        );
        assertEq(IERC20(token).balanceOf(address(wrap)), fee);
    }

    function _testDepositFees(uint256 amount) internal override {
        assertEq(
            wrap.exposed_depositFees(amount),
            wrap.exposed_calculateFee(amount, protocolFeeBPS)
        );
    }

    function _testOnExecute(uint256 amount)
        internal
        override
        withToken
        withMintedTokens(address(wrap), amount)
    {
        uint256 initialAccumulatedProtocolFees = wmb.accumalatedProtocolFees(
            token
        );
        uint256 initialRecipientBalance = IERC20(token).balanceOf(user);
        uint256 protocolFee = wrap.exposed_calculateFee(amount, protocolFeeBPS);
        uint256 fee = protocolFee +
            wrap.exposed_calculateFee(amount, validatorsFeeBPS);

        vm.expectEmit(true, true, true, true, token);
        emit Transfer(address(0), user, amount - fee);
        vm.expectEmit(true, true, true, true, token);
        emit Transfer(address(0), address(wrap), fee);
        assertEq(wrap.exposed_onExecute(token, amount, user), fee);
        assertEq(
            wmb.accumalatedProtocolFees(token),
            initialAccumulatedProtocolFees + protocolFee
        );
        assertEq(
            IERC20(token).balanceOf(user),
            initialRecipientBalance + (amount - fee)
        );
    }

    function _testExecuteFees(uint256 amount) internal override {
        assertEq(
            wrap.exposed_executeFees(amount),
            wrap.exposed_calculateFee(amount, validatorsFeeBPS + protocolFeeBPS)
        );
    }

    function testConfigureFees() public {
        uint16 newProtocolFeeBPS = protocolFeeBPS / 2;
        uint16 newValidatorsFeeBPS = validatorsFeeBPS / 2;
        vm.prank(admin);
        wmb.configureFees(newProtocolFeeBPS, newValidatorsFeeBPS);
        assertEq(wmb.protocolFeeBPS(), newProtocolFeeBPS);
        assertEq(wmb.validatorsFeeBPS(), newValidatorsFeeBPS);
    }

    function testConfigureFeesCanBeSetToZero() public {
        vm.prank(admin);
        wmb.configureFees(0, 0);
        assertEq(wmb.protocolFeeBPS(), 0);
        assertEq(wmb.validatorsFeeBPS(), 0);
    }

    function testConfigureFeesRevertsIfFeeExceedsMax() public {
        uint16 maxFeeBPS = wmb.exposed_maxFeeBPS();
        vm.startPrank(admin);
        vm.expectRevert(IWrap.FeeExceedsMaxFee.selector);
        wmb.configureFees(maxFeeBPS + 1, maxFeeBPS);
        vm.expectRevert(IWrap.FeeExceedsMaxFee.selector);
        wmb.configureFees(maxFeeBPS, maxFeeBPS + 1);
        vm.stopPrank();
    }

    function testConfigureFeesRevertsIfCallerIsNotAdmin() public {
        vm.prank(user);
        _expectMissingRoleRevert(user, DEFAULT_ADMIN_ROLE);
        wmb.configureFees(protocolFeeBPS / 2, validatorsFeeBPS / 2);
    }

    function testCreateAddToken() public {
        vm.prank(admin);
        token = wmb.createAddToken(
            testTokenName,
            testTokenSymbol,
            mirrorToken,
            mirrorTokenDecimals,
            tokenInfo
        );

        _assertCorrectAddTokenState();
    }

    function testCreateAddTokenRevertsIfCallerIsNotAdmin() public {
        vm.prank(user);
        _expectMissingRoleRevert(user, DEFAULT_ADMIN_ROLE);
        wmb.createAddToken(
            testTokenName,
            testTokenSymbol,
            mirrorToken,
            mirrorTokenDecimals,
            tokenInfo
        );
    }

    function _claimValidatorFees() internal override {
        wmb.claimValidatorFees();
    }

    function _accumulatedValidatorsFees()
        internal
        view
        override
        returns (uint256)
    {
        uint256 contractBalance = IERC20(token).balanceOf(address(wrap));
        return contractBalance - wmb.accumalatedProtocolFees(token);
    }

    function testClaimProtocolFees() public withToken withSigners {
        uint256 expectedProtocolFee = 0;

        _executeApproveExecute(1000, user);
        expectedProtocolFee += wrap.exposed_calculateFee(1000, protocolFeeBPS);
        _executeDeposit(1000, user);
        expectedProtocolFee += wrap.exposed_calculateFee(1000, protocolFeeBPS);
        _executeApproveExecute(1000, user);
        expectedProtocolFee += wrap.exposed_calculateFee(1000, protocolFeeBPS);
        _executeDeposit(1000, user);
        expectedProtocolFee += wrap.exposed_calculateFee(1000, protocolFeeBPS);

        uint256 initialAdminBalance = IERC20(token).balanceOf(admin);
        uint256 initialContractBalance = IERC20(token).balanceOf(address(wrap));

        assertEq(wmb.accumalatedProtocolFees(token), expectedProtocolFee);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true, token);
        emit Transfer(address(wrap), admin, expectedProtocolFee);
        wmb.claimProtocolFees(token);

        assertEq(wmb.accumalatedProtocolFees(token), 0);
        assertEq(
            IERC20(token).balanceOf(admin),
            initialAdminBalance + expectedProtocolFee
        );
        assertEq(
            IERC20(token).balanceOf(address(wrap)),
            initialContractBalance - expectedProtocolFee
        );
    }

    function testClaimProtocolFeesRevertsIfCallerIsNotAdmin()
        public
        withToken
        withSigners
    {
        assertFalse(wrap.hasRole(DEFAULT_ADMIN_ROLE, user));
        _executeApproveExecute(1000, user);
        _executeDeposit(1000, user);
        vm.prank(user);
        _expectMissingRoleRevert(user, DEFAULT_ADMIN_ROLE);
        wmb.claimProtocolFees(token);
    }

    function _expectDepositEvents(
        uint256 depositIndex,
        address token,
        uint256 amount,
        uint256 fee,
        address recipient
    ) internal override {
        vm.expectEmit(true, true, true, true);
        emit Transfer(recipient, address(0), amount - fee);
        vm.expectEmit(true, true, true, true);
        emit Transfer(recipient, address(wrap), fee);
        vm.expectEmit(true, true, true, true);
        emit Deposit(depositIndex, token, amount - fee, recipient, fee);
    }

    function _expectDepositFinalContractBalance(
        uint256 initialContractBalance,
        uint256 amount
    ) internal override {
        assertEq(
            IERC20(token).balanceOf(address(wrap)),
            initialContractBalance +
                wrap.exposed_calculateFee(amount, protocolFeeBPS)
        );
    }

    // TODO: Rename modifier
    modifier updatesAccumulatedProtocolFees(uint256 amount) {
        uint256 initialAccumulatedProtocolFees = wmb.accumalatedProtocolFees(
            token
        );

        uint256 fee = wrap.exposed_calculateFee(amount, protocolFeeBPS);
        _;
        assertEq(
            wmb.accumalatedProtocolFees(token),
            initialAccumulatedProtocolFees + fee
        );
    }

    function _testDepositUpdatesAccumulatedProtocolFees(uint256 amount)
        internal
        withMintedTokens(user, amount)
        updatesAccumulatedProtocolFees(amount)
    {
        _executeDeposit(amount, user);
    }

    function testDepositUpdatesAccumulatedProtocolFees() public withToken {
        uint256 minAmountWithFees = tokenInfo.minAmount +
            wrap.exposed_depositFees(tokenInfo.minAmount);

        _testDepositUpdatesAccumulatedProtocolFees(minAmountWithFees);
        _testDepositUpdatesAccumulatedProtocolFees(minAmountWithFees + 1);
        _testDepositUpdatesAccumulatedProtocolFees(minAmountWithFees + 2);
        _testDepositUpdatesAccumulatedProtocolFees(tokenInfo.maxAmount - 2);
        _testDepositUpdatesAccumulatedProtocolFees(tokenInfo.maxAmount - 1);
    }

    function testDepositUpdatesAccumulatedProtocolFees(uint256 amount)
        public
        withToken
    {
        vm.assume(
            amount >=
                tokenInfo.minAmount +
                    wrap.exposed_depositFees(tokenInfo.minAmount)
        );

        vm.assume(amount < tokenInfo.maxAmount);
        _testDepositUpdatesAccumulatedProtocolFees(amount);
    }

    function _testApproveExecuteUpdatesAccumulatedProtocolFees(uint256 amount)
        internal
        withMintedTokens(user, amount)
        updatesAccumulatedProtocolFees(amount)
    {
        _executeApproveExecute(amount, user);
    }

    function testApproveExecuteUpdatesAccumulatedProtocolFees()
        public
        withToken
        withSigners
    {
        _testApproveExecuteUpdatesAccumulatedProtocolFees(tokenInfo.minAmount);
        _testApproveExecuteUpdatesAccumulatedProtocolFees(
            tokenInfo.minAmount + 1
        );
        _testApproveExecuteUpdatesAccumulatedProtocolFees(
            tokenInfo.minAmount + 2
        );
        _testApproveExecuteUpdatesAccumulatedProtocolFees(
            tokenInfo.maxAmount - 2
        );
        _testApproveExecuteUpdatesAccumulatedProtocolFees(
            tokenInfo.maxAmount - 1
        );
    }

    function testApproveExecuteUpdatesAccumulatedProtocolFees(uint256 amount)
        public
        withToken
        withSigners
    {
        vm.assume(amount >= tokenInfo.minAmount);

        vm.assume(amount < tokenInfo.maxAmount);
        _testApproveExecuteUpdatesAccumulatedProtocolFees(amount);
    }

    function _expectApproveExecuteFinalEvents(
        uint256 id,
        address token,
        uint256 amount,
        address recipient
    ) internal override {
        uint256 fee = wrap.exposed_executeFees(amount);
        vm.expectEmit(true, true, true, true, token);
        emit Transfer(address(0), recipient, amount - fee);
        vm.expectEmit(true, true, true, true, token);
        emit Transfer(address(0), address(wrap), fee);
        vm.expectEmit(true, true, true, true, address(wrap));
        emit Executed(id, token, amount - fee, recipient, fee);
    }

    function _expectApproveExecuteFinalContractBalance(
        uint256 initialContractBalance,
        uint256,
        uint256 fee
    ) internal override {
        assertEq(
            IERC20(token).balanceOf(address(wrap)),
            initialContractBalance + fee
        );
    }
}
