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

        validatorFeeBPS = 100;

        vm.prank(admin);
        wmb = new WrapMintBurnHarness(config, protocolFeeBPS, validatorFeeBPS);
        wrap = WrapHarness(wmb);
    }

    function testConstructorProtocolFeeBPS() public {
        assertEq(wmb.protocolFeeBPS(), protocolFeeBPS);
    }

    function testConstructorValidatorFeeBPS() public {
        assertEq(wmb.validatorFeeBPS(), validatorFeeBPS);
    }

    function _testOnDeposit(
        uint256 userInitialBalance,
        uint256 amountToDeposit
    ) internal override withToken withMintedTokens(user, userInitialBalance) {
        /*uint256 initialAccumulatedProtocolFees = wmb.accumulatedProtocolFees(
            token
        );*/
        uint256 fee = wrap.exposed_depositFees(amountToDeposit);
        vm.startPrank(user);
        IERC20(token).approve(address(wrap), amountToDeposit);
        vm.expectEmit(true, true, true, true, token);
        emit Transfer(user, address(0), amountToDeposit - fee);
        vm.expectEmit(true, true, true, true, token);
        emit Transfer(user, address(wrap), fee);
        assertEq(wrap.exposed_onDeposit(token, amountToDeposit), fee);
        vm.stopPrank();
        /*assertEq(
            wmb.accumulatedProtocolFees(token),
            initialAccumulatedProtocolFees + fee
        );*/
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

    function _onExecuteFee(
        uint256 amount
    ) internal view override returns (uint256) {
        return
            wrap.exposed_calculateFee(amount, protocolFeeBPS) +
            wrap.exposed_calculateFee(amount, validatorFeeBPS);
    }

    function _onExecutePerformExternalAction(
        address,
        uint256,
        address,
        uint256
    ) internal override {}

    function _testOnExecute(
        uint256 amount
    ) internal override withToken withMintedTokens(address(wrap), amount) {
        /*uint256 initialAccumulatedProtocolFees = wmb.accumulatedProtocolFees(
            token
        );*/
        uint256 initialRecipientBalance = IERC20(token).balanceOf(user);
        uint256 protocolFee = wrap.exposed_calculateFee(amount, protocolFeeBPS);
        uint256 fee = protocolFee +
            wrap.exposed_calculateFee(amount, validatorFeeBPS);

        vm.expectEmit(true, true, true, true, token);
        emit Transfer(address(0), user, amount - fee);
        vm.expectEmit(true, true, true, true, token);
        emit Transfer(address(0), address(wrap), fee);
        assertEq(wrap.exposed_onExecute(token, amount, user), fee);
        /*assertEq(
            wmb.accumulatedProtocolFees(token),
            initialAccumulatedProtocolFees + protocolFee
        );*/
        assertEq(
            IERC20(token).balanceOf(user),
            initialRecipientBalance + (amount - fee)
        );
    }

    function testConfigureProtocolFees() public {
        uint16 newProtocolFeeBPS = protocolFeeBPS / 2;
        vm.prank(admin);
        wmb.configureProtocolFees(newProtocolFeeBPS);
        assertEq(wmb.protocolFeeBPS(), newProtocolFeeBPS);
    }

    function testConfigureProtocolFeesCanBeSetToZero() public {
        vm.prank(admin);
        wmb.configureProtocolFees(0);
        assertEq(wmb.protocolFeeBPS(), 0);
    }

    function testConfigureProtocolFeesRevertsIfFeeExceedsMax() public {
        uint16 maxFeeBPS = wmb.exposed_maxFeeBPS();
        vm.startPrank(admin);
        vm.expectRevert(IWrap.FeeExceedsMaxFee.selector);
        wmb.configureProtocolFees(maxFeeBPS + 1);
        vm.stopPrank();
    }

    function testConfigureProtocolFeesRevertsIfCallerIsNotAdmin() public {
        vm.prank(user);
        _expectMissingRoleRevert(user, DEFAULT_ADMIN_ROLE);
        wmb.configureProtocolFees(protocolFeeBPS / 2);
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

    /*function _accumulatedValidatorFees()
        internal
        view
        override
        returns (uint256)
    {
        uint256 contractBalance = IERC20(token).balanceOf(address(wrap));
        return contractBalance - wmb.accumulatedProtocolFees(token);
    }*/

    function testClaimProtocolFees() public withToken withValidators {
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
        uint256 initialCustodianBalance = IERC20(token).balanceOf(_custodian());

        //assertEq(wmb.accumulatedProtocolFees(token), expectedProtocolFee);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true, token);
        emit Transfer(address(wrap), admin, expectedProtocolFee);
        wmb.claimProtocolFees(token);

        //assertEq(wmb.accumulatedProtocolFees(token), 0);
        assertEq(
            IERC20(token).balanceOf(admin),
            initialAdminBalance + expectedProtocolFee
        );
        assertEq(
            IERC20(token).balanceOf(address(wrap)),
            initialCustodianBalance - expectedProtocolFee
        );
    }

    function testClaimProtocolFeesRevertsIfCallerIsNotAdmin()
        public
        withToken
        withValidators
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

    function _custodian() internal view override returns (address) {
        return address(wrap);
    }

    function _expectDepositFinalCustodianBalance(
        uint256 initialCustodianBalance,
        uint256 amount
    ) internal override {
        assertEq(
            IERC20(token).balanceOf(_custodian()),
            initialCustodianBalance +
                wrap.exposed_calculateFee(amount, protocolFeeBPS)
        );
    }

    /*
    // TODO: Rename modifier
    modifier updatesAccumulatedProtocolFees(uint256 amount) {
        uint256 initialAccumulatedProtocolFees = wmb.accumulatedProtocolFees(
            token
        );

        uint256 fee = wrap.exposed_calculateFee(amount, protocolFeeBPS);
        _;
        assertEq(
            wmb.accumulatedProtocolFees(token),
            initialAccumulatedProtocolFees + fee
        );
    }

    function _testDepositUpdatesAccumulatedProtocolFees(
        uint256 amount
    )
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

    function testDepositUpdatesAccumulatedProtocolFees(
        uint256 amount
    ) public withToken {
        vm.assume(
            amount >=
                tokenInfo.minAmount +
                    wrap.exposed_depositFees(tokenInfo.minAmount)
        );

        vm.assume(amount < tokenInfo.maxAmount);
        _testDepositUpdatesAccumulatedProtocolFees(amount);
    }

    function _testApproveExecuteUpdatesAccumulatedProtocolFees(
        uint256 amount
    )
        internal
        withMintedTokens(user, amount)
        updatesAccumulatedProtocolFees(amount)
    {
        _executeApproveExecute(amount, user);
    }

    function testApproveExecuteUpdatesAccumulatedProtocolFees()
        public
        withToken
        withValidators
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

    function testApproveExecuteUpdatesAccumulatedProtocolFees(
        uint256 amount
    ) public withToken withValidators {
        vm.assume(amount >= tokenInfo.minAmount);

        vm.assume(amount < tokenInfo.maxAmount);
        _testApproveExecuteUpdatesAccumulatedProtocolFees(amount);
    }*/

    function _expectApproveExecuteFinalEvents(
        uint256 id,
        address token,
        uint256 amount,
        address recipient,
        uint256 fee
    ) internal override {
        vm.expectEmit(true, true, true, true, token);
        emit Transfer(address(0), recipient, amount - fee);
        vm.expectEmit(true, true, true, true, token);
        emit Transfer(address(0), address(wrap), fee);
        vm.expectEmit(true, true, true, true, address(wrap));
        emit Executed(id, token, amount - fee, recipient, fee);
    }

    function _expectApproveExecuteFinalCustodianBalance(
        uint256 initialCustodianBalance,
        uint256,
        uint256 fee
    ) internal override {
        assertEq(
            IERC20(token).balanceOf(_custodian()),
            initialCustodianBalance + fee
        );
    }
}
