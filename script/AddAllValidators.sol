// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/interfaces/IWrap.sol";
import "./utils/Constants.sol";

contract AddAllValidators is Script, Constants {
    address constant wrap = APOTHEM;

    //address constant wrap = COSTON;

    function run() external {
        vm.startBroadcast();
        for (uint16 i = 0; i < validators.length; i++) {
            console.log(
                "-----------------------------------------------------------"
            );
            console.log("Adding validator %s", validators[i]);
            console.log("Fee Recipient: %s:", validatorFeeRecipients[i]);
            console.log("Is first commitee: %s:", isFirstCommittees[i]);

            IWrap(wrap).addValidator(
                validators[i],
                isFirstCommittees[i],
                validatorFeeRecipients[i]
            );
        }
        vm.stopBroadcast();
    }
}
