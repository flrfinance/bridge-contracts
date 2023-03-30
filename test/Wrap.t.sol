// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IWrap } from "../src/interfaces/IWrap.sol";
import { WrapHarness } from "../src/test/WrapHarness.sol";
import { Multisig } from "../src/libraries/Multisig.sol";
import { TestAsserter } from "./utils/TestAsserter.sol";
import { MultisigHelpers } from "./utils/MultisigHelpers.sol";

abstract contract WrapTest is TestAsserter, MultisigHelpers {
    address constant admin = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address constant pauser = 0x88A52Ace8A863B91e77c766eB1DD5f11780E2430;
    address constant user = 0x85bAd7dC21CC7a95549b5D957Ef6f9813b5B4141;

    string testTokenName = "TestERC20";
    string testTokenSymbol = "TT";

    bytes32 PAUSE_ROLE = keccak256("PAUSE");
    bytes32 DEFAULT_ADMIN_ROLE = 0x00;

    Multisig.Config config;
    WrapHarness wrap;
    uint16 validatorFeeBPS;

    address token;
    address mirrorToken;
    IWrap.TokenInfo tokenInfo;

    address validator;
    address validatorFeeRecipient;

    address validatorA;
    address validatorAFeeRecipient;
    address validatorB;
    address validatorBFeeRecipient;

    event Deposit(
        uint256 indexed id,
        address indexed token,
        uint256 amount,
        address to,
        uint256 fee
    );

    event Requested(
        uint256 indexed id,
        address indexed mirrorToken,
        uint256 amount,
        address to
    );

    event Executed(
        uint256 indexed id,
        address indexed mirrorToken,
        address indexed token,
        uint256 amount,
        address to,
        uint256 fee
    );

    event Transfer(address indexed from, address indexed to, uint256 value);

    modifier withPauser() {
        vm.prank(admin);
        wrap.grantRole(PAUSE_ROLE, pauser);
        _;
    }

    function _pause() internal withPauser {
        vm.prank(pauser);
        wrap.pause();
    }

    modifier withPaused() {
        _pause();
        _;
    }

    function _addValidator(Committee committee) internal {
        vm.prank(admin);
        wrap.addValidator(
            validator,
            committee == Committee.First ? true : false,
            validatorFeeRecipient
        );
    }

    modifier withValidator(Committee committee) {
        _addValidator(committee);
        _;
    }

    modifier withAnyValidator() {
        _addValidator(
            block.number % 2 == 0 ? Committee.First : Committee.Second
        );
        _;
    }

    // TODO: Add >2 validators
    modifier withValidators() {
        vm.startPrank(admin);
        wrap.addValidator(validatorA, true, validatorAFeeRecipient);
        wrap.addValidator(validatorB, false, validatorBFeeRecipient);
        vm.stopPrank();
        _;
    }

    function _addToken() internal virtual;

    modifier withToken() {
        _addToken();
        _;
    }

    function _mintTokens(address account, uint256 amount) internal virtual;

    modifier withMintedTokens(address account, uint256 amount) {
        _mintTokens(account, amount);
        _;
    }

    modifier withTokenInfo(IWrap.TokenInfo memory newTokenInfo) {
        vm.prank(admin);
        tokenInfo = newTokenInfo;
        wrap.configureToken(token, newTokenInfo);
        _;
    }

    function _expectMissingRoleRevert(address account, bytes32 role) internal {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(account),
                " is missing role ",
                Strings.toHexString(uint256(role), 32)
            )
        );
    }

    function _assertCorrectAddTokenState() internal {
        uint256 tokensLength = wrap.exposed_tokensLength();
        assertEq(wrap.exposed_tokens(tokensLength - 1), address(token));
        (
            uint256 maxAmount,
            uint256 minAmount,
            uint256 minAmountWithFees,
            uint256 dailyLimit,
            uint256 consumedLimit,
            uint256 lastUpdated
        ) = wrap.tokenInfos(address(token));
        assertEq(maxAmount, tokenInfo.maxAmount);
        assertEq(minAmount, tokenInfo.minAmount);
        assertEq(
            minAmountWithFees,
            tokenInfo.minAmount + wrap.exposed_depositFees(tokenInfo.minAmount)
        );
        assertEq(dailyLimit, tokenInfo.dailyLimit);
        assertEq(consumedLimit, 0);
        assertEq(lastUpdated, block.timestamp);
        assertEq(wrap.mirrorTokens(mirrorToken), address(token));
    }

    function _executeApproveExecute(
        uint256 amount,
        address recipient
    )
        internal
        withMintedTokens(_custodian(), amount)
        returns (uint256 requestId)
    {
        requestId = wrap.nextExecutionIndex();
        (uint256 fee, ) = _onExecuteFee(amount);
        vm.prank(validatorA);
        wrap.approveExecute(
            requestId,
            mirrorToken,
            amount,
            recipient,
            blockhash(block.number - 1),
            block.number - 1
        );
        vm.prank(validatorB);
        wrap.approveExecute(
            requestId,
            mirrorToken,
            amount,
            recipient,
            blockhash(block.number - 1),
            block.number - 1
        );
        _onExecutePerformExternalAction(token, amount, user, fee);
    }

    function _executeDeposit(
        uint256 amount,
        address depositor
    ) internal withMintedTokens(depositor, amount) returns (uint256) {
        vm.startPrank(user);
        IERC20(token).approve(address(wrap), amount);
        uint256 id = wrap.deposit(token, amount, user);
        vm.stopPrank();
        return id;
    }

    function _generateMirrorToken() internal view returns (address) {
        return address(uint160(wrap.exposed_tokensLength()) + 1);
    }

    constructor() {
        config = Multisig.Config(
            firstCommitteeAcceptanceQuorum,
            secondCommitteeAcceptanceQuorum
        );

        tokenInfo = IWrap.TokenInfo({
            maxAmount: 10_000,
            minAmount: 100,
            dailyLimit: 1e40
        });
        validator = signer;
        validatorFeeRecipient = address(1);

        validatorA = signerA;
        validatorAFeeRecipient = address(2);
        validatorB = signerB;
        validatorBFeeRecipient = address(3);

        // You cannot `approveExecute` on genesis because
        // you need a previous block to exist
        vm.roll(2);
    }

    function testConstructorSetupRole() public {
        assertTrue(wrap.hasRole(wrap.DEFAULT_ADMIN_ROLE(), admin));
    }

    function testConstructorMultisigConfigure() public {
        (
            uint8 actualFirstCommitteeAcceptanceQuorum,
            uint8 actualSecondCommitteeAcceptanceQuorum
        ) = wrap.exposed_multisigCommittee();
        assertEq(
            actualFirstCommitteeAcceptanceQuorum,
            firstCommitteeAcceptanceQuorum
        );
        assertEq(
            actualSecondCommitteeAcceptanceQuorum,
            secondCommitteeAcceptanceQuorum
        );
    }

    function _testOnDeposit(
        uint256 userInitialBalance,
        uint256 amountToDeposit
    ) internal virtual;

    function testOnDeposit() public {
        uint256 userInitialBalance = 1337;
        uint256 amountToDeposit = 1000;
        _testOnDeposit(userInitialBalance, amountToDeposit);
        userInitialBalance = 1337;
        amountToDeposit = 0;
        _testOnDeposit(userInitialBalance, amountToDeposit);
        userInitialBalance = 1337;
        amountToDeposit = 1337;
        _testOnDeposit(userInitialBalance, amountToDeposit);
        userInitialBalance = 0;
        amountToDeposit = 0;
        _testOnDeposit(userInitialBalance, amountToDeposit);
    }

    function testOnDeposit(
        uint256 userInitialBalance,
        uint256 amountToDeposit
    ) public {
        vm.assume(amountToDeposit < ((2 ** 256) - 1) / uint256((2 ** 16) - 1));
        vm.assume(amountToDeposit <= userInitialBalance);
        _testOnDeposit(userInitialBalance, amountToDeposit);
    }

    function _testDepositFees(uint256 amount) internal virtual;

    function testDepositFees() public {
        _testDepositFees(0);
        _testDepositFees(789);
        _testDepositFees(31337);
        _testDepositFees(4e9);
        _testDepositFees(382e20);
    }

    function testDepositFees(uint256 amount) public {
        vm.assume(amount < ((2 ** 256) - 1) / uint256((2 ** 16) - 1));
        _testDepositFees(amount);
    }

    function _testOnExecute(uint256 amount) internal virtual;

    function testOnExecute() public {
        _testOnExecute(0);
        _testOnExecute(40);
        _testOnExecute(1337);
        _testOnExecute(1e20);
        _testOnExecute(8e30);
    }

    function testOnExecute(uint256 amount) public {
        vm.assume(amount < ((2 ** 256) - 1) / uint256((2 ** 16) - 1));
        _testOnExecute(amount);
    }

    function testNextExecutionIndex() public withToken withValidators {
        uint256 amount = tokenInfo.minAmount + 1;
        assertEq(wrap.nextExecutionIndex(), 0);
        _executeApproveExecute(amount, user);
        assertEq(wrap.nextExecutionIndex(), 1);
        _executeApproveExecute(amount, user);
        assertEq(wrap.nextExecutionIndex(), 2);
        _executeApproveExecute(amount, user);
        assertEq(wrap.nextExecutionIndex(), 3);
    }

    function testValidatorInfo() public withValidators {
        Multisig.SignerInfo memory signerInfoA = wrap.validatorInfo(validatorA);
        _assertEq(signerInfoA.status, Multisig.SignerStatus.FirstCommittee);
        assertEq(signerInfoA.index, 0);

        Multisig.SignerInfo memory signerInfoB = wrap.validatorInfo(validatorB);
        _assertEq(signerInfoB.status, Multisig.SignerStatus.SecondCommittee);
        assertEq(signerInfoB.index, 1);
    }

    function testAttesters() public withToken withValidators {
        uint256 amount = tokenInfo.minAmount + 1;
        uint256 requestId = _executeApproveExecute(amount, user);
        bytes32 hash = wrap.exposed_hashRequest(
            requestId,
            mirrorToken,
            amount,
            user
        );
        uint16[] memory expectedAttesters = new uint16[](2);
        expectedAttesters[0] = 0;
        expectedAttesters[1] = 1;
        (uint16[] memory attesters, uint16 count) = wrap.attesters(hash);
        assertEq(count, 2);
        _assertEq(attesters, expectedAttesters);
    }

    function testCalculateFee() public {
        uint256 amount = 1337;
        uint16 feeBPS = 500;
        assertEq(
            wrap.exposed_calculateFee(amount, feeBPS),
            (amount * feeBPS) / 10000
        );
    }

    function testCalculateFee(uint256 amount, uint16 feeBPS) public {
        vm.assume(amount < ((2 ** 256) - 1) / uint256((2 ** 16) - 1));
        assertEq(
            wrap.exposed_calculateFee(amount, feeBPS),
            (amount * feeBPS) / 10000
        );
    }

    function testConfigureValidatorFeeRecipient()
        public
        withToken
        withValidators
    {
        address newValidatorAFeeRecipient = address(4242);
        vm.prank(admin);
        wrap.configureValidatorFeeRecipient(
            validatorA,
            newValidatorAFeeRecipient
        );
        assertEq(
            wrap.validatorFeeRecipients(validatorA),
            newValidatorAFeeRecipient
        );

        address newValidatorBFeeRecipient = address(1717);
        vm.prank(admin);
        wrap.configureValidatorFeeRecipient(
            validatorB,
            newValidatorBFeeRecipient
        );
        assertEq(
            wrap.validatorFeeRecipients(validatorB),
            newValidatorBFeeRecipient
        );
    }

    function testConfigureValidatorFeeRecipientIfCallerIsNotAdmin()
        public
        withToken
        withValidators
    {
        vm.prank(user);
        _expectMissingRoleRevert(user, DEFAULT_ADMIN_ROLE);
        wrap.configureValidatorFeeRecipient(validatorA, address(4242));

        vm.prank(user);
        _expectMissingRoleRevert(user, DEFAULT_ADMIN_ROLE);
        wrap.configureValidatorFeeRecipient(validatorB, address(1717));
    }

    function testClaimValidatorFeesRevertsIfAddressNotInRecipient()
        public
        withToken
        withValidators
    {
        vm.prank(user);
        (address random, ) = makeAddrAndKey("random");
        vm.expectRevert(IWrap.InvalidToAddress.selector);
        wrap.claimValidatorFees(random);
    }

    function testClaimValidatorFees() public withToken withValidators {
        uint8 validatorAIndex = wrap
            .exposed_multisigSignerInfo(validatorA)
            .index;
        uint8 validatorBIndex = wrap
            .exposed_multisigSignerInfo(validatorB)
            .index;

        uint256 expectedValidatorAFeeBalance = wrap.feeBalance(
            token,
            validatorAIndex
        );
        uint256 expectedValidatorBFeeBalance = wrap.feeBalance(
            token,
            validatorBIndex
        );

        // TODO: Create helper function
        (, uint256 validatorFee) = _onExecuteFee(1000);
        uint256 feeToValidator = validatorFee / 2;
        _executeApproveExecute(1000, user);
        expectedValidatorAFeeBalance += feeToValidator;
        expectedValidatorBFeeBalance += feeToValidator;

        (, validatorFee) = _onExecuteFee(2000);
        feeToValidator = validatorFee / 2;
        _executeApproveExecute(2000, user);
        expectedValidatorAFeeBalance += feeToValidator;
        expectedValidatorBFeeBalance += feeToValidator;

        (, validatorFee) = _onExecuteFee(3000);
        feeToValidator = validatorFee / 2;
        _executeApproveExecute(3000, user);
        expectedValidatorAFeeBalance += feeToValidator;
        expectedValidatorBFeeBalance += feeToValidator;

        _executeDeposit(4000, user); // should not affect validator fees

        uint256 initialValidatorABalance = IERC20(token).balanceOf(
            validatorAFeeRecipient
        );
        uint256 initialValidatorBBalance = IERC20(token).balanceOf(
            validatorBFeeRecipient
        );
        uint256 initialCustodianBalance = IERC20(token).balanceOf(_custodian());

        assertEq(
            wrap.feeBalance(token, validatorAIndex),
            expectedValidatorAFeeBalance
        );
        assertEq(
            wrap.feeBalance(token, validatorBIndex),
            expectedValidatorBFeeBalance
        );

        vm.prank(user);
        vm.expectEmit(true, true, true, true, token);
        emit Transfer(
            address(wrap),
            validatorAFeeRecipient,
            expectedValidatorAFeeBalance
        );
        wrap.claimValidatorFees(validatorA);

        assertEq(wrap.feeBalance(token, validatorAIndex), 0);

        vm.prank(user);
        vm.expectEmit(true, true, true, true, token);
        emit Transfer(
            address(wrap),
            validatorBFeeRecipient,
            expectedValidatorBFeeBalance
        );
        wrap.claimValidatorFees(validatorB);

        assertEq(wrap.feeBalance(token, validatorBIndex), 0);

        assertEq(
            IERC20(token).balanceOf(validatorAFeeRecipient),
            initialValidatorABalance + expectedValidatorAFeeBalance
        );
        assertEq(
            IERC20(token).balanceOf(validatorBFeeRecipient),
            initialValidatorBBalance + expectedValidatorBFeeBalance
        );
        assertEq(
            IERC20(token).balanceOf(_custodian()),
            initialCustodianBalance -
                (expectedValidatorAFeeBalance + expectedValidatorBFeeBalance)
        );
    }

    function testClaimValidatorFeesForRemovedValidator()
        public
        withToken
        withValidators
    {
        uint8 validatorAIndex = wrap
            .exposed_multisigSignerInfo(validatorA)
            .index;

        uint256 expectedValidatorAFeeBalance = wrap.feeBalance(
            token,
            validatorAIndex
        );

        (, uint256 validatorFee) = _onExecuteFee(1000);
        _executeApproveExecute(1000, user);
        expectedValidatorAFeeBalance += validatorFee / 2;

        uint256 initialValidatorABalance = IERC20(token).balanceOf(
            validatorAFeeRecipient
        );

        assertEq(
            wrap.feeBalance(token, validatorAIndex),
            expectedValidatorAFeeBalance
        );

        vm.prank(admin);
        wrap.removeValidator(validatorA);

        vm.prank(user);
        vm.expectEmit(true, true, true, true, token);
        emit Transfer(
            address(wrap),
            validatorAFeeRecipient,
            expectedValidatorAFeeBalance
        );
        wrap.claimValidatorFees(validatorA);

        assertEq(wrap.feeBalance(token, validatorAIndex), 0);

        assertEq(
            IERC20(token).balanceOf(validatorAFeeRecipient),
            initialValidatorABalance + expectedValidatorAFeeBalance
        );
    }

    function _expectDepositEvents(
        uint256 depositIndex,
        address token,
        uint256 amount,
        uint256 fee,
        address recipient
    ) internal virtual;

    // Either the contract itself or the address of the custodian
    function _custodian() internal view virtual returns (address);

    function _expectDepositFinalCustodianBalance(
        uint256 initialCustodianBalance,
        uint256 amount
    ) internal virtual;

    function _testDeposit(
        uint256 amount
    ) internal withMintedTokens(user, amount) {
        uint256 initialDepositorBalance = IERC20(token).balanceOf(user);
        uint256 initialCustodianBalance = IERC20(token).balanceOf(_custodian());

        uint256 fee = wrap.exposed_depositFees(amount);

        vm.startPrank(user);
        IERC20(token).approve(address(wrap), amount);

        uint256 initialDepositIndex = wrap.depositIndex();
        _expectDepositEvents(initialDepositIndex, token, amount, fee, user);
        uint256 id = wrap.deposit(token, amount, user);
        vm.stopPrank();

        assertEq(id, initialDepositIndex);
        assertEq(wrap.depositIndex(), initialDepositIndex + 1);
        assertEq(
            IERC20(token).balanceOf(user),
            initialDepositorBalance - amount
        );
        _expectDepositFinalCustodianBalance(initialCustodianBalance, amount);
    }

    function testDeposit() public withToken {
        uint256 minAmountWithFees = tokenInfo.minAmount +
            wrap.exposed_depositFees(tokenInfo.minAmount);
        _testDeposit(minAmountWithFees);
        _testDeposit(minAmountWithFees + 1);
        _testDeposit(minAmountWithFees + 2);
        _testDeposit(tokenInfo.maxAmount - 2);
        _testDeposit(tokenInfo.maxAmount - 1);
    }

    function testDepositWithDailyLimitAmount()
        public
        withToken
        withTokenInfo(
            IWrap.TokenInfo({
                maxAmount: 2 ** 256 - 1,
                minAmount: 100,
                dailyLimit: 1000
            })
        )
    {
        (, , , uint256 dailyLimit, uint256 consumedLimit, ) = wrap.tokenInfos(
            token
        );
        _testDeposit(dailyLimit - consumedLimit);
    }

    function testDeposit(uint256 amount) public withToken {
        vm.assume(
            amount >
                tokenInfo.minAmount +
                    wrap.exposed_depositFees(tokenInfo.minAmount)
        );
        vm.assume(amount < tokenInfo.maxAmount);
        _testDeposit(amount);
    }

    function _testDepositRevertsIfContractsPaused(
        uint256 amount
    ) internal withMintedTokens(user, amount) {
        vm.startPrank(user);
        IERC20(token).approve(address(wrap), amount);
        vm.expectRevert(IWrap.ContractPaused.selector);
        wrap.deposit(token, amount, user);
        vm.stopPrank();
    }

    function testDepositRevertsIfContractsPaused() public withToken withPaused {
        uint256 minAmountWithFees = tokenInfo.minAmount +
            wrap.exposed_depositFees(tokenInfo.minAmount);
        _testDepositRevertsIfContractsPaused(minAmountWithFees);
        _testDepositRevertsIfContractsPaused(minAmountWithFees + 1);
        _testDepositRevertsIfContractsPaused(minAmountWithFees + 2);
        _testDepositRevertsIfContractsPaused(tokenInfo.maxAmount - 2);
        _testDepositRevertsIfContractsPaused(tokenInfo.maxAmount - 1);
    }

    function testDepositRevertsIfContractsPaused(
        uint256 amount
    ) public withToken withPaused {
        vm.assume(
            amount >
                tokenInfo.minAmount +
                    wrap.exposed_depositFees(tokenInfo.minAmount)
        );
        vm.assume(amount < tokenInfo.maxAmount);
        _testDepositRevertsIfContractsPaused(amount);
    }

    function _testDepositRevertsWithInvalidTokenAmount(
        uint256 amount
    ) internal withMintedTokens(user, amount) {
        vm.startPrank(user);
        IERC20(token).approve(address(wrap), amount);
        vm.expectRevert(IWrap.InvalidTokenAmount.selector);
        wrap.deposit(token, amount, user);
        vm.stopPrank();
    }

    function testDepositRevertsIfAmountIsLessThanMinAmountWithFees()
        public
        withToken
    {
        uint256 minAmountWithFees = tokenInfo.minAmount +
            wrap.exposed_depositFees(tokenInfo.minAmount);
        _testDepositRevertsWithInvalidTokenAmount(minAmountWithFees - 1);
        _testDepositRevertsWithInvalidTokenAmount(minAmountWithFees - 2);
        _testDepositRevertsWithInvalidTokenAmount(0);
    }

    function testDepositRevertsIfAmountIsLessThanMinAmountWithFees(
        uint256 amount
    ) public withToken {
        vm.assume(
            amount <
                tokenInfo.minAmount +
                    wrap.exposed_depositFees(tokenInfo.minAmount)
        );
        _testDepositRevertsWithInvalidTokenAmount(amount);
    }

    function testDepositRevertsIfAmountIsGreaterThanMaxAmount()
        public
        withToken
    {
        _testDepositRevertsWithInvalidTokenAmount(tokenInfo.maxAmount + 1);
        _testDepositRevertsWithInvalidTokenAmount(tokenInfo.maxAmount + 2);
        _testDepositRevertsWithInvalidTokenAmount(tokenInfo.maxAmount + 3);
    }

    function testDepositRevertsIfAmountIsGreaterThanMaxAmount(
        uint256 amount
    ) public withToken {
        vm.assume(amount > tokenInfo.maxAmount);
        _testDepositRevertsWithInvalidTokenAmount(amount);
    }

    function _testDepositRevertsWhenDailyLimitExhausted(
        uint256 amount
    ) internal withMintedTokens(user, amount) {
        vm.startPrank(user);
        IERC20(token).approve(address(wrap), amount);
        vm.expectRevert(IWrap.DailyLimitExhausted.selector);
        wrap.deposit(token, amount, user);
        vm.stopPrank();
    }

    function testDepositRevertsWhenDailyLimitExhausted()
        public
        withToken
        withTokenInfo(
            IWrap.TokenInfo({
                maxAmount: 2 ** 256 - 1,
                minAmount: 100,
                dailyLimit: 1000
            })
        )
    {
        (, , , uint256 dailyLimit, uint256 consumedLimit, ) = wrap.tokenInfos(
            token
        );
        _testDepositRevertsWhenDailyLimitExhausted(
            dailyLimit - consumedLimit + 1
        );
    }

    function testDepositDailyLimitResets()
        public
        withToken
        withMintedTokens(user, 2000)
        withTokenInfo(
            IWrap.TokenInfo({
                maxAmount: 2 ** 256 - 1,
                minAmount: 100,
                dailyLimit: 1000
            })
        )
    {
        uint256 dailyLimit = tokenInfo.dailyLimit;
        vm.startPrank(user);
        IERC20(token).approve(address(wrap), 2 ** 256 - 1);

        wrap.deposit(token, dailyLimit / 2, user);
        wrap.deposit(token, dailyLimit / 2, user);

        vm.expectRevert(IWrap.DailyLimitExhausted.selector);
        wrap.deposit(token, 1000, user);

        (, , , , , uint256 lastUpdated) = wrap.tokenInfos(token);

        vm.warp(lastUpdated + 1 days + 1);
        wrap.deposit(token, 1000, user);

        vm.stopPrank();
    }

    function _testDepositRevertsIfToAddressIsInvalid(
        uint256 amount
    ) internal withMintedTokens(user, amount) {
        vm.startPrank(user);
        IERC20(token).approve(address(wrap), amount);
        vm.expectRevert(IWrap.InvalidToAddress.selector);
        wrap.deposit(token, amount, address(0));
        vm.stopPrank();
    }

    function testDepositRevertsIfToAddressIsInvalid() public withToken {
        uint256 minAmountWithFees = tokenInfo.minAmount +
            wrap.exposed_depositFees(tokenInfo.minAmount);
        _testDepositRevertsIfToAddressIsInvalid(minAmountWithFees);
        _testDepositRevertsIfToAddressIsInvalid(minAmountWithFees + 1);
        _testDepositRevertsIfToAddressIsInvalid(minAmountWithFees + 2);
        _testDepositRevertsIfToAddressIsInvalid(tokenInfo.maxAmount - 2);
        _testDepositRevertsIfToAddressIsInvalid(tokenInfo.maxAmount - 1);
    }

    function testDepositRevertsIfToAddressIsInvalid(
        uint256 amount
    ) public withToken {
        vm.assume(
            amount >
                tokenInfo.minAmount +
                    wrap.exposed_depositFees(tokenInfo.minAmount)
        );
        vm.assume(amount < tokenInfo.maxAmount);
        _testDepositRevertsIfToAddressIsInvalid(amount);
    }

    function _testHashRequest(
        uint256 id,
        address token_,
        uint256 amount,
        address to
    ) internal {
        assertEq(
            wrap.exposed_hashRequest(id, token_, amount, to),
            keccak256(abi.encodePacked(id, token_, amount, to))
        );
    }

    function testHashRequest() public {
        uint256 id = 1337;
        uint256 amount = 31337;
        address to = user;
        _testHashRequest(id, token, amount, to);
    }

    function testHashRequest(
        uint256 id,
        address token_,
        uint256 amount,
        address to
    ) public {
        _testHashRequest(id, token_, amount, to);
    }

    function _expectApproveExecuteFinalEvents(
        uint256 id,
        address token,
        uint256 amount,
        address recipient,
        uint256 fee
    ) internal virtual;

    function _expectApproveExecuteFinalCustodianBalance(
        uint256 initialCustodianBalance,
        uint256 totalAmount,
        uint256 totalFees
    ) internal virtual;

    function _onExecuteFee(
        uint256 amount
    ) internal virtual returns (uint256 fee, uint256 validatorFee);

    // Custodian should transfer amount to recipient
    // on WrapDepositRedeemCustodian
    function _onExecutePerformExternalAction(
        address token,
        uint256 amount,
        address recipient,
        uint256 fee
    ) internal virtual;

    function _testApproveExecute(
        uint256 amount
    ) internal withToken withMintedTokens(_custodian(), amount) {
        uint256 initialNextExecutionIndex = wrap.nextExecutionIndex();

        uint256 requestId = initialNextExecutionIndex;
        uint256 initialRecipientBalance = IERC20(token).balanceOf(user);
        uint256 initialCustodianBalance = IERC20(token).balanceOf(_custodian());

        vm.prank(validatorA);
        vm.expectEmit(true, true, true, true);
        emit Requested(requestId, mirrorToken, amount, user);
        wrap.approveExecute(
            requestId,
            mirrorToken,
            amount,
            user,
            blockhash(block.number - 1),
            block.number - 1
        );

        assertEq(IERC20(token).balanceOf(user), initialRecipientBalance);
        assertEq(
            IERC20(token).balanceOf(_custodian()),
            initialCustodianBalance
        );

        (uint256 fee, uint256 validatorFee) = _onExecuteFee(amount);

        _onExecutePerformExternalAction(token, amount, user, fee);

        _expectApproveExecuteFinalEvents(requestId, token, amount, user, fee);

        vm.prank(validatorB);
        wrap.approveExecute(
            requestId,
            mirrorToken,
            amount,
            user,
            blockhash(block.number - 1),
            block.number - 1
        );

        bytes32 hash = wrap.exposed_hashRequest(
            requestId,
            mirrorToken,
            amount,
            user
        );

        uint8 validatorAIndex = wrap
            .exposed_multisigSignerInfo(validatorA)
            .index;
        uint8 validatorBIndex = wrap
            .exposed_multisigSignerInfo(validatorB)
            .index;

        {
            (uint16[] memory approvers, uint16 count) = wrap
                .exposed_multisigGetApprovers(hash);
            assertEq(count, 2);
            assertEq(approvers.length, 2);
            assertEq(approvers[0], validatorAIndex);
            assertEq(approvers[1], validatorBIndex);
        }

        uint256 feeToValidator = validatorFee / 2;
        assertEq(wrap.feeBalance(token, validatorAIndex), feeToValidator);
        assertEq(wrap.feeBalance(token, validatorBIndex), feeToValidator);

        assertEq(
            IERC20(token).balanceOf(user),
            initialRecipientBalance + amount - fee
        );
        _expectApproveExecuteFinalCustodianBalance(
            initialCustodianBalance,
            amount,
            fee
        );

        assertEq(wrap.nextExecutionIndex(), initialNextExecutionIndex + 1);
    }

    function testApproveExecute() public withToken withValidators {
        _testApproveExecute(tokenInfo.minAmount);
        _testApproveExecute(tokenInfo.minAmount + 1);
        _testApproveExecute(tokenInfo.minAmount + 2);
        _testApproveExecute(tokenInfo.maxAmount - 2);
        _testApproveExecute(tokenInfo.maxAmount - 1);
    }

    function testApproveExecute(
        uint256 amount
    ) public withToken withValidators {
        vm.assume(amount > tokenInfo.minAmount);
        vm.assume(amount < tokenInfo.maxAmount);
        _testApproveExecute(amount);
    }

    function _testApproveExecuteRevertsIfBlockHashIsInvalid(
        uint256 amount,
        bytes32 recentBlockHash,
        uint256 recentBlockNumber
    ) internal withMintedTokens(user, amount) {
        uint256 initialNextExecutionIndex = wrap.nextExecutionIndex();
        uint256 requestId = initialNextExecutionIndex;
        vm.prank(validatorA);
        vm.expectRevert(IWrap.InvalidBlockHash.selector);
        wrap.approveExecute(
            requestId,
            mirrorToken,
            amount,
            user,
            recentBlockHash,
            recentBlockNumber
        );
    }

    function _testApproveExecuteRevertsIfBlockHashDoesNotMatchBlockNumber(
        uint256 amount
    ) internal {
        _testApproveExecuteRevertsIfBlockHashIsInvalid(
            amount,
            blockhash(block.number - 1),
            block.number - 2
        );
    }

    function testApproveExecuteRevertsIfBlockHashDoesNotMatchBlockNumber()
        public
        withToken
        withValidators
    {
        _testApproveExecuteRevertsIfBlockHashDoesNotMatchBlockNumber(
            tokenInfo.minAmount
        );
        _testApproveExecuteRevertsIfBlockHashDoesNotMatchBlockNumber(
            tokenInfo.minAmount + 1
        );
        _testApproveExecuteRevertsIfBlockHashDoesNotMatchBlockNumber(
            tokenInfo.minAmount + 2
        );
        _testApproveExecuteRevertsIfBlockHashDoesNotMatchBlockNumber(
            tokenInfo.maxAmount - 2
        );
        _testApproveExecuteRevertsIfBlockHashDoesNotMatchBlockNumber(
            tokenInfo.maxAmount - 1
        );
    }

    function testApproveExecuteRevertsIfBlockHashDoesNotMatchBlockNumber(
        uint256 amount,
        bytes32 recentBlockHash,
        uint256 recentBlockNumber
    ) public withToken withValidators {
        vm.assume(amount > tokenInfo.minAmount);
        vm.assume(amount < tokenInfo.maxAmount);
        vm.assume(blockhash(recentBlockNumber) != recentBlockHash);
        _testApproveExecuteRevertsIfBlockHashIsInvalid(
            amount,
            recentBlockHash,
            recentBlockNumber
        );
    }

    function _testApproveExecuteRevertsIfBlockHashIsZero(
        uint256 amount,
        uint256 recentBlockNumber
    ) internal {
        _testApproveExecuteRevertsIfBlockHashIsInvalid(
            amount,
            bytes32(0),
            recentBlockNumber
        );
    }

    function testApproveExecuteRevertsIfBlockHashIsZero()
        public
        withToken
        withValidators
    {
        uint256 recentBlockNumber = block.number - 1;
        _testApproveExecuteRevertsIfBlockHashIsZero(
            tokenInfo.minAmount,
            recentBlockNumber
        );
        _testApproveExecuteRevertsIfBlockHashIsZero(
            tokenInfo.minAmount + 1,
            recentBlockNumber
        );
        _testApproveExecuteRevertsIfBlockHashIsZero(
            tokenInfo.minAmount + 2,
            recentBlockNumber
        );
        _testApproveExecuteRevertsIfBlockHashIsZero(
            tokenInfo.maxAmount - 2,
            recentBlockNumber
        );
        _testApproveExecuteRevertsIfBlockHashIsZero(
            tokenInfo.maxAmount - 1,
            recentBlockNumber
        );
    }

    function testApproveExecuteRevertsIfBlockHashIsZero(
        uint256 amount,
        uint256 recentBlockNumber
    ) public withToken withValidators {
        vm.assume(amount > tokenInfo.minAmount);
        vm.assume(amount < tokenInfo.maxAmount);
        _testApproveExecuteRevertsIfBlockHashIsInvalid(
            amount,
            bytes32(0),
            recentBlockNumber
        );
    }

    function _testApproveExecuteRevertsIfBlockNumberIsOld(
        uint256 amount
    ) internal {
        uint256 recentBlockNumber = block.number - 1;
        bytes32 recentBlockHash = blockhash(recentBlockNumber);
        vm.roll(recentBlockNumber + 256 + 1);
        _testApproveExecuteRevertsIfBlockHashIsInvalid(
            amount,
            recentBlockHash,
            recentBlockNumber
        );
    }

    function testApproveExecuteRevertsIfBlockNumberIsOld()
        public
        withToken
        withValidators
    {
        _testApproveExecuteRevertsIfBlockNumberIsOld(tokenInfo.minAmount);
        _testApproveExecuteRevertsIfBlockNumberIsOld(tokenInfo.minAmount + 1);
        _testApproveExecuteRevertsIfBlockNumberIsOld(tokenInfo.minAmount + 2);
        _testApproveExecuteRevertsIfBlockNumberIsOld(tokenInfo.maxAmount - 2);
        _testApproveExecuteRevertsIfBlockNumberIsOld(tokenInfo.maxAmount - 1);
    }

    function testApproveExecuteRevertsIfBlockNumberIsOld(
        uint256 amount
    ) public withToken withValidators {
        vm.assume(amount > tokenInfo.minAmount);
        vm.assume(amount < tokenInfo.maxAmount);
        _testApproveExecuteRevertsIfBlockNumberIsOld(amount);
    }

    function _testApproveExecuteRevertsIfBlockNumberIsOldAndBlockHashIsZero(
        uint256 amount
    ) internal {
        uint256 recentBlockNumber = block.number - 1;
        vm.roll(recentBlockNumber + 256 + 1);
        _testApproveExecuteRevertsIfBlockHashIsInvalid(
            amount,
            bytes32(0),
            recentBlockNumber
        );
    }

    function testApproveExecuteRevertsIfBlockNumberIsOldAndBlockHashIsZero()
        public
        withToken
        withValidators
    {
        _testApproveExecuteRevertsIfBlockNumberIsOldAndBlockHashIsZero(
            tokenInfo.minAmount
        );
        _testApproveExecuteRevertsIfBlockNumberIsOldAndBlockHashIsZero(
            tokenInfo.minAmount + 1
        );
        _testApproveExecuteRevertsIfBlockNumberIsOldAndBlockHashIsZero(
            tokenInfo.minAmount + 2
        );
        _testApproveExecuteRevertsIfBlockNumberIsOldAndBlockHashIsZero(
            tokenInfo.maxAmount - 2
        );
        _testApproveExecuteRevertsIfBlockNumberIsOldAndBlockHashIsZero(
            tokenInfo.maxAmount - 1
        );
    }

    function testApproveExecuteRevertsIfBlockNumberIsOldAndBlockHashIsZero(
        uint256 amount
    ) public withToken withValidators {
        vm.assume(amount > tokenInfo.minAmount);
        vm.assume(amount < tokenInfo.maxAmount);
        _testApproveExecuteRevertsIfBlockNumberIsOldAndBlockHashIsZero(amount);
    }

    function _testApproveExecuteRevertsIfContractsPaused(
        uint256 amount
    ) internal withMintedTokens(user, amount) {
        uint256 initialNextExecutionIndex = wrap.nextExecutionIndex();
        uint256 requestId = initialNextExecutionIndex;
        vm.prank(validatorA);
        vm.expectRevert(IWrap.ContractPaused.selector);
        wrap.approveExecute(
            requestId,
            mirrorToken,
            amount,
            user,
            blockhash(block.number - 1),
            block.number - 1
        );
    }

    function testApproveExecuteRevertsIfContractsPaused()
        public
        withToken
        withValidators
        withPaused
    {
        _testApproveExecuteRevertsIfContractsPaused(tokenInfo.minAmount);
        _testApproveExecuteRevertsIfContractsPaused(tokenInfo.minAmount + 1);
        _testApproveExecuteRevertsIfContractsPaused(tokenInfo.minAmount + 2);
        _testApproveExecuteRevertsIfContractsPaused(tokenInfo.maxAmount - 2);
        _testApproveExecuteRevertsIfContractsPaused(tokenInfo.maxAmount - 1);
    }

    function testApproveExecuteRevertsIfContractsPaused(
        uint256 amount
    ) public withToken withValidators withPaused {
        vm.assume(amount > tokenInfo.minAmount);
        vm.assume(amount < tokenInfo.maxAmount);
        _testApproveExecuteRevertsIfContractsPaused(amount);
    }

    function _testApproveExecuteRevertsWithInvalidTokenAmount(
        uint256 amount
    ) internal withMintedTokens(user, amount) {
        uint256 initialNextExecutionIndex = wrap.nextExecutionIndex();
        uint256 requestId = initialNextExecutionIndex;
        vm.prank(validatorA);
        vm.expectRevert(IWrap.InvalidTokenAmount.selector);
        wrap.approveExecute(
            requestId,
            mirrorToken,
            amount,
            user,
            blockhash(block.number - 1),
            block.number - 1
        );
    }

    function testApproveExecuteRevertsIfAmountIsLessThanMinAmount()
        public
        withToken
        withValidators
    {
        _testApproveExecuteRevertsWithInvalidTokenAmount(
            tokenInfo.minAmount - 1
        );
        _testApproveExecuteRevertsWithInvalidTokenAmount(
            tokenInfo.minAmount - 2
        );
        _testApproveExecuteRevertsWithInvalidTokenAmount(0);
    }

    function testApproveExecuteRevertsIfAmountIsLessThanMinAmount(
        uint256 amount
    ) public withToken withValidators {
        vm.assume(amount < tokenInfo.minAmount);
        _testApproveExecuteRevertsWithInvalidTokenAmount(amount);
    }

    function testApproveExecuteRevertsIfAmountIsGreaterThanMaxAmount()
        public
        withToken
        withValidators
    {
        _testApproveExecuteRevertsWithInvalidTokenAmount(
            tokenInfo.maxAmount + 1
        );
        _testApproveExecuteRevertsWithInvalidTokenAmount(
            tokenInfo.maxAmount + 2
        );
        _testApproveExecuteRevertsWithInvalidTokenAmount(
            tokenInfo.maxAmount + 3
        );
    }

    function testApproveExecuteRevertsIfAmountIsGreaterThanMaxAmount(
        uint256 amount
    ) public withToken withValidators {
        vm.assume(amount > tokenInfo.maxAmount);
        _testApproveExecuteRevertsWithInvalidTokenAmount(amount);
    }

    function _expectBatchApproveExecuteFinalEvents(
        IWrap.RequestInfo memory request,
        uint256 fee
    ) internal {
        _expectApproveExecuteFinalEvents(
            request.id,
            token,
            request.amount,
            request.to,
            fee
        );
    }

    function _testBatchApproveExecute(
        IWrap.RequestInfo[] memory requests,
        uint256 totalAmount
    ) internal withMintedTokens(_custodian(), totalAmount) {
        uint256 initialNextExecutionIndex = wrap.nextExecutionIndex();
        uint256 initialRecipientBalance = IERC20(token).balanceOf(user);
        uint256 initialCustodianBalance = IERC20(token).balanceOf(_custodian());

        for (uint256 i = 0; i < requests.length; i++) {
            IWrap.RequestInfo memory request = requests[i];
            vm.expectEmit(true, true, true, true);
            emit Requested(
                request.id,
                request.token,
                request.amount,
                request.to
            );
        }

        vm.prank(validatorA);
        wrap.batchApproveExecute(
            requests,
            blockhash(block.number - 1),
            block.number - 1
        );

        assertEq(IERC20(token).balanceOf(user), initialRecipientBalance);

        uint256 totalFees = 0;
        for (uint256 i = 0; i < requests.length; i++) {
            IWrap.RequestInfo memory request = requests[i];
            (uint256 fee, ) = _onExecuteFee(request.amount);
            totalFees += fee;
            _onExecutePerformExternalAction(
                token,
                request.amount,
                request.to,
                fee
            );
            _expectBatchApproveExecuteFinalEvents(request, fee);
        }

        vm.prank(validatorB);
        wrap.batchApproveExecute(
            requests,
            blockhash(block.number - 1),
            block.number - 1
        );

        _expectApproveExecuteFinalCustodianBalance(
            initialCustodianBalance,
            totalAmount,
            totalFees
        );
        assertEq(
            IERC20(token).balanceOf(user),
            initialRecipientBalance + totalAmount - totalFees
        );
        assertEq(
            wrap.nextExecutionIndex(),
            initialNextExecutionIndex + requests.length
        );
    }

    function _testBatchApproveExecute(uint256 requestCount) internal {
        vm.assume(requestCount > 0);
        vm.assume(requestCount < 100);

        IWrap.RequestInfo[] memory requests = new IWrap.RequestInfo[](
            requestCount
        );
        uint256 initialRequestId = wrap.nextExecutionIndex();
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < requestCount; i++) {
            uint256 amount = 1337;
            totalAmount += amount;
            requests[i] = IWrap.RequestInfo({
                id: initialRequestId + i,
                token: mirrorToken, // TODO: random new tokens
                amount: amount, // TODO: random `amount`
                to: user // TODO: random `to`
            });
        }

        _testBatchApproveExecute(requests, totalAmount);
    }

    function testBatchApproveExecute() public withToken withValidators {
        _testBatchApproveExecute(1);
        _testBatchApproveExecute(5);
        _testBatchApproveExecute(20);
    }

    function testBatchApproveExecute(
        uint256 requestCount
    ) public withToken withValidators {
        _testBatchApproveExecute(requestCount);
    }

    function testConfigureToken() public withToken {
        vm.prank(admin);
        uint256 newMaxAmount = 1337;
        uint256 newMinAmount = 10;
        uint256 newDailyLimit = 100 * 10 ** 18;
        IWrap.TokenInfo memory newTokenInfo = IWrap.TokenInfo({
            maxAmount: newMaxAmount,
            minAmount: newMinAmount,
            dailyLimit: newDailyLimit
        });
        wrap.configureToken(token, newTokenInfo);

        (
            uint256 maxAmount,
            uint256 minAmount,
            uint256 minAmountWithFees,
            uint256 dailyLimit,
            uint256 consumedLimit,
            uint256 lastUpdated
        ) = wrap.tokenInfos(token);

        assertEq(maxAmount, newMaxAmount);
        assertEq(minAmount, newMinAmount);
        assertEq(
            minAmountWithFees,
            newMinAmount + wrap.exposed_depositFees(newMinAmount)
        );
        assertEq(dailyLimit, newDailyLimit);
        assertEq(consumedLimit, 0);
        assertEq(lastUpdated, block.timestamp);
    }

    function testConfigureTokenRevertsIfMinAmountIsZero() public withToken {
        vm.prank(admin);
        vm.expectRevert(IWrap.InvalidTokenConfig.selector);
        wrap.configureToken(
            token,
            IWrap.TokenInfo({ maxAmount: 100, minAmount: 0, dailyLimit: 0 })
        );
    }

    function testConfigureTokenRevertsIfTokenHasNotBeenAdded() public {
        vm.prank(admin);
        vm.expectRevert(IWrap.InvalidTokenConfig.selector);
        wrap.configureToken(token, tokenInfo);
    }

    function testConfigureTokenRevertsIfCallerIsNotAdmin() public withToken {
        vm.prank(user);
        _expectMissingRoleRevert(user, DEFAULT_ADMIN_ROLE);
        wrap.configureToken(token, tokenInfo);
    }

    function testConfigureValidatorFees() public {
        uint16 newValidatorFeeBPS = validatorFeeBPS / 2;
        vm.prank(admin);
        wrap.configureValidatorFees(newValidatorFeeBPS);
        assertEq(wrap.validatorFeeBPS(), newValidatorFeeBPS);
    }

    function testConfigureValidatorFeesCanBeSetToZero() public {
        vm.prank(admin);
        wrap.configureValidatorFees(0);
        assertEq(wrap.validatorFeeBPS(), 0);
    }

    function testConfigureValidatorFeesRevertsIfFeeExceedsMax() public {
        uint16 maxFeeBPS = wrap.exposed_maxFeeBPS();
        vm.startPrank(admin);
        vm.expectRevert(IWrap.FeeExceedsMaxFee.selector);
        wrap.configureValidatorFees(maxFeeBPS + 1);
        vm.stopPrank();
    }

    function testConfigureValidatorFeesRevertsIfCallerIsNotAdmin() public {
        vm.prank(user);
        _expectMissingRoleRevert(user, DEFAULT_ADMIN_ROLE);
        wrap.configureValidatorFees(validatorFeeBPS / 2);
    }

    function test_addToken() public {
        wrap.exposed__addToken(token, mirrorToken, tokenInfo);
        _assertCorrectAddTokenState();
    }

    function test_addTokenRevertsIfMinAmountIsZero() public {
        tokenInfo = IWrap.TokenInfo({
            maxAmount: 10_000,
            minAmount: 0,
            dailyLimit: 0
        });
        vm.expectRevert(IWrap.InvalidTokenConfig.selector);
        wrap.exposed__addToken(token, mirrorToken, tokenInfo);
    }

    function test_addTokenRevertsIfTokenAlreadyExists() public {
        wrap.exposed__addToken(address(1), address(2), tokenInfo);
        vm.expectRevert(IWrap.InvalidTokenConfig.selector);
        wrap.exposed__addToken(address(1), address(3), tokenInfo);
    }

    function test_addTokenRevertsIfMirrorTokenAlreadyExists() public {
        wrap.exposed__addToken(address(31337), address(8), tokenInfo);
        vm.expectRevert(IWrap.InvalidTokenConfig.selector);
        wrap.exposed__addToken(address(1337), address(8), tokenInfo);
    }

    function testConfigureMultisig() public {
        Multisig.Config memory newConfig = Multisig.Config(10, 30);
        vm.prank(admin);
        wrap.configureMultisig(newConfig);
        (
            uint8 actualFirstCommitteeAcceptanceQuorum,
            uint8 actualSecondCommitteeAcceptanceQuorum
        ) = wrap.exposed_multisigCommittee();
        assertEq(
            actualFirstCommitteeAcceptanceQuorum,
            newConfig.firstCommitteeAcceptanceQuorum
        );
        assertEq(
            actualSecondCommitteeAcceptanceQuorum,
            newConfig.secondCommitteeAcceptanceQuorum
        );
    }

    function testConfigureMultisigRevertsIfCallerIsNotAdmin() public {
        Multisig.Config memory newConfig = Multisig.Config(10, 30);
        vm.prank(user);
        _expectMissingRoleRevert(user, DEFAULT_ADMIN_ROLE);
        wrap.configureMultisig(newConfig);
    }

    function testPause() public withPauser {
        assertFalse(wrap.paused());
        vm.prank(pauser);
        wrap.pause();
        assertTrue(wrap.paused());
    }

    function testPauseIfAlreadyPaused() public withPaused {
        assertTrue(wrap.paused());
        vm.prank(pauser);
        wrap.pause();
        assertTrue(wrap.paused());
    }

    function testPauseRevertsIfCallerIsNotPauser() public {
        assertFalse(wrap.hasRole(PAUSE_ROLE, user));
        vm.prank(user);
        _expectMissingRoleRevert(user, PAUSE_ROLE);
        wrap.pause();
    }

    function testUnpause() public withPaused {
        assertTrue(wrap.paused());
        vm.prank(admin);
        wrap.unpause();
        assertFalse(wrap.paused());
    }

    function testUnpauseIfAlreadyUnpaused() public {
        assertFalse(wrap.paused());
        vm.prank(admin);
        wrap.unpause();
        assertFalse(wrap.paused());
    }

    function testUnpauseRevertsIfCallerIsPauserButNotAdmin() public withPaused {
        assertTrue(wrap.hasRole(PAUSE_ROLE, pauser));
        assertFalse(wrap.hasRole(DEFAULT_ADMIN_ROLE, pauser));
        vm.prank(pauser);
        _expectMissingRoleRevert(pauser, DEFAULT_ADMIN_ROLE);
        wrap.unpause();
    }

    function testUnpauseRevertsIfCallerIsNotAdmin() public withPaused {
        assertFalse(wrap.hasRole(DEFAULT_ADMIN_ROLE, user));
        vm.prank(user);
        _expectMissingRoleRevert(user, DEFAULT_ADMIN_ROLE);
        wrap.unpause();
    }

    function _testAddValidator(Committee committee) internal {
        uint8 initialFirstCommitteeSize = wrap
            .exposed_multisigFirstCommitteeSize();
        uint8 initialSecondCommitteeSize = wrap
            .exposed_multisigSecondCommitteeSize();
        vm.prank(admin);
        wrap.addValidator(
            validator,
            committee == Committee.First,
            validatorFeeRecipient
        );
        Multisig.SignerInfo memory validatorInfo = wrap
            .exposed_multisigSignerInfo(validator);
        _assertEq(
            validatorInfo.status,
            committee == Committee.First
                ? Multisig.SignerStatus.FirstCommittee
                : Multisig.SignerStatus.SecondCommittee
        );
        uint8 finalFirstCommitteeSize = wrap
            .exposed_multisigFirstCommitteeSize();
        uint8 finalSecondCommitteeSize = wrap
            .exposed_multisigSecondCommitteeSize();
        assertEq(
            validatorInfo.index,
            finalFirstCommitteeSize + finalSecondCommitteeSize - 1
        );
        assertEq(
            wrap.exposed_multisigFirstCommitteeSize(),
            committee == Committee.First
                ? initialFirstCommitteeSize + 1
                : initialFirstCommitteeSize
        );
        assertEq(
            wrap.exposed_multisigSecondCommitteeSize(),
            committee == Committee.First
                ? initialSecondCommitteeSize
                : initialSecondCommitteeSize + 1
        );

        assertEq(wrap.validatorFeeRecipients(validator), validatorFeeRecipient);
    }

    function testAddValidatorToFirstCommittee() public {
        _testAddValidator(Committee.First);
    }

    function testAddValidatorToSecondCommittee() public {
        _testAddValidator(Committee.Second);
    }

    function testAddValidatorToFirstCommitteeRevertsIfCallerIsNotAdmin()
        public
    {
        vm.prank(user);
        _expectMissingRoleRevert(user, DEFAULT_ADMIN_ROLE);
        wrap.addValidator(validator, true, validatorFeeRecipient);
    }

    function testAddValidatorToSecondCommitteeRevertsIfCallerIsNotAdmin()
        public
    {
        vm.prank(user);
        _expectMissingRoleRevert(user, DEFAULT_ADMIN_ROLE);
        wrap.addValidator(validator, false, validatorFeeRecipient);
    }

    function _testRemoveValidator(
        Committee committee
    ) internal withValidator(committee) {
        vm.prank(admin);
        wrap.removeValidator(validator);
        Multisig.SignerInfo memory validatorInfo = wrap
            .exposed_multisigSignerInfo(validator);
        _assertEq(validatorInfo.status, Multisig.SignerStatus.Removed);
    }

    function testRemoveValidatorFromFirstCommittee() public {
        _testRemoveValidator(Committee.First);
    }

    function testRemoveValidatorFromSecondCommittee() public {
        _testRemoveValidator(Committee.Second);
    }

    function testRemoveValidatorFromFirstCommitteeRevertsIfCallerIsNotAdmin()
        public
        withValidator(Committee.First)
    {
        vm.prank(user);
        _expectMissingRoleRevert(user, DEFAULT_ADMIN_ROLE);
        wrap.removeValidator(validator);
    }

    function testRemoveValidatorFromSecondCommitteeRevertsIfCallerIsNotAdmin()
        public
        withValidator(Committee.Second)
    {
        vm.prank(user);
        _expectMissingRoleRevert(user, DEFAULT_ADMIN_ROLE);
        wrap.removeValidator(validator);
    }

    function testForceSetNextExecutionIndexRevertsIfCallerIsNotAdmin() public {
        uint256 newNextExecutionIndex = wrap.nextExecutionIndex() + 1;
        vm.prank(user);
        _expectMissingRoleRevert(user, DEFAULT_ADMIN_ROLE);
        wrap.forceSetNextExecutionIndex(newNextExecutionIndex);
    }

    function testForceSetNextExecutionIndex() public {
        uint256 newNextExecutionIndex = wrap.nextExecutionIndex() + 1;
        vm.prank(admin);
        wrap.forceSetNextExecutionIndex(newNextExecutionIndex);
    }
}
