// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Multisig } from "../libraries/Multisig.sol";
import { WrapMintBurn } from "../WrapMintBurn.sol";
import { WrapHarness } from "./WrapHarness.sol";

contract WrapMintBurnHarness is WrapHarness, WrapMintBurn {
    constructor(
        Multisig.Config memory config,
        uint16 _protocolFeeBPS,
        uint16 _validatorsFeeBPS
    ) WrapMintBurn(config, _protocolFeeBPS, _validatorsFeeBPS) {}

    function exposed_maxFeeBPS() external pure returns (uint16) {
        return WrapMintBurn.maxFeeBPS;
    }
}
