// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Multisig } from "../src/libraries/Multisig.sol";
import { WrapDepositRedeemTest } from "./WrapDepositRedeem.t.sol";
import {
    WrapDepositRedeemCustodianHarness
} from "../src/test/WrapDepositRedeemCustodianHarness.sol";
import {
    WrapDepositRedeemHarness
} from "../src/test/WrapDepositRedeemHarness.sol";
import { WrapHarness } from "../src/test/WrapHarness.sol";

contract WrapDepositRedeemCustodianTest is WrapDepositRedeemTest {
    address custodian = address(0xca5);
    WrapDepositRedeemCustodianHarness wdrc;

    constructor() {
        config = Multisig.Config(
            firstCommitteeAcceptanceQuorum,
            secondCommitteeAcceptanceQuorum
        );

        validatorFeeBPS = 100;

        vm.prank(admin);
        wdrc = new WrapDepositRedeemCustodianHarness(
            config,
            validatorFeeBPS,
            custodian
        );
        wdr = WrapDepositRedeemHarness(address(wdrc));
        wrap = WrapHarness(wdr);
    }

    function _custodian() internal view override returns (address) {
        return custodian;
    }

    function _testOnDeposit(
        uint256 userInitialBalance,
        uint256 amountToDeposit
    ) internal override withToken withMintedTokens(user, userInitialBalance) {
        uint256 initialCustodianBalance = IERC20(token).balanceOf(custodian);
        uint256 initialContractBalance = IERC20(token).balanceOf(address(wrap));
        vm.startPrank(user);
        IERC20(token).approve(address(wrap), amountToDeposit);
        vm.expectEmit(true, true, true, true, token);
        emit Transfer(user, custodian, amountToDeposit);
        assertEq(wrap.exposed_onDeposit(token, amountToDeposit), 0);
        vm.stopPrank();
        assertEq(
            IERC20(token).balanceOf(user),
            userInitialBalance - amountToDeposit
        );
        assertEq(
            IERC20(token).balanceOf(custodian),
            initialCustodianBalance + amountToDeposit
        );
        assertEq(
            IERC20(token).balanceOf(address(wrap)),
            initialContractBalance
        );
    }

    function _onExecutePerformExternalAction(
        address token,
        uint256 amount,
        address recipient,
        uint256 fee
    ) internal override {
        vm.prank(_custodian());
        IERC20(token).transfer(recipient, amount - fee);
    }

    function _expectApproveExecuteFinalEvents(
        uint256 id,
        address token,
        uint256 amount,
        address recipient,
        uint256 fee
    ) internal override {
        // No transfer event is emitted since the custodian
        // is expected to transfer directly to the recipient
        vm.expectEmit(true, true, true, true, address(wrap));
        emit Executed(id, token, amount - fee, recipient, fee);
    }

    function _testOnExecute(
        uint256 amount
    ) internal override withToken withMintedTokens(address(wrap), amount) {
        uint256 initialRecipientBalance = IERC20(token).balanceOf(user);
        uint256 fee = _onExecuteFee(amount);
        assertEq(wrap.exposed_onExecute(token, amount, user), fee);
        assertEq(IERC20(token).balanceOf(user), initialRecipientBalance);
    }
}
