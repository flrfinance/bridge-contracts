// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Multisig } from "../libraries/Multisig.sol";
import { WrapDepositRedeemCustodian } from "../WrapDepositRedeemCustodian.sol";
import { WrapDepositRedeem } from "../WrapDepositRedeem.sol";
import { Wrap } from "../Wrap.sol";
import { WrapHarness } from "./WrapHarness.sol";

contract WrapDepositRedeemCustodianHarness is
    WrapHarness,
    WrapDepositRedeemCustodian
{
    constructor(
        Multisig.Config memory config,
        uint16 _validatorsFeeBPS,
        address custodian
    ) WrapDepositRedeemCustodian(config, _validatorsFeeBPS, custodian) {}

    function accumulatedValidatorFees(
        address token
    ) public view virtual override(Wrap, WrapDepositRedeem) returns (uint256) {
        return super.accumulatedValidatorFees(token);
    }
}
