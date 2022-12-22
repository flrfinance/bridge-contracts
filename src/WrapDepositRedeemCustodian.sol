// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { WrapDepositRedeem } from "./WrapDepositRedeem.sol";
import { Multisig } from "./libraries/Multisig.sol";

contract WrapDepositRedeemCustodian is WrapDepositRedeem {
    using SafeERC20 for IERC20;

    address public immutable custodian;

    constructor(
        Multisig.Config memory config,
        uint16 _validatorsFeeBPS,
        address _custodian
    ) WrapDepositRedeem(config, _validatorsFeeBPS) {
        custodian = _custodian;
    }

    function onDeposit(address token, uint256 amount)
        internal
        override
        returns (uint256)
    {
        IERC20(token).safeTransferFrom(msg.sender, custodian, amount);
        return depositFees(amount);
    }

    function onExecute(
        address,
        uint256 amount,
        address
    ) internal view override returns (uint256 fee) {
        fee = calculateFee(amount, validatorsFeeBPS);
    }
}
