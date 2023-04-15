// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/interfaces/IWrap.sol";
import "./utils/Constants.sol";
import { Multisig } from "../src/libraries/Multisig.sol";

contract CheckAllValidators is Script, Constants {
    address constant wrap = APOTHEM;

    //address constant wrap = COSTON;

    function run() external {
        for (uint16 i = 0; i < validators.length; i++) {
            console.log(
                "-----------------------------------------------------------"
            );
            console.log("Checking validator %s", validators[i]);
            Multisig.SignerInfo memory signerInfo = IWrap(wrap).validatorInfo(
                validators[i]
            );
            console.log(
                "status: %s",
                VALIDATOR_STATUS[uint(signerInfo.status)]
            );
            console.log("index: %d", signerInfo.index);
        }
    }
}
