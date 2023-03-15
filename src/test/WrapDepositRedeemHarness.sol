// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Multisig } from "../libraries/Multisig.sol";
import { WrapDepositRedeem } from "../WrapDepositRedeem.sol";
import { Wrap } from "../Wrap.sol";
import { WrapHarness } from "./WrapHarness.sol";

contract WrapDepositRedeemHarness is WrapHarness, WrapDepositRedeem {
    constructor(
        Multisig.Config memory config,
        uint16 _validatorsFeeBPS
    ) WrapDepositRedeem(config, _validatorsFeeBPS) {}
}
