// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/interfaces/IWrap.sol";
import "./utils/Constants.sol";

contract AddValidator is Script, Constants {
    address constant wrap = APOTHEM;
    //address constant wrap = COSTON;

    address constant validator = 0x20FDcb0063d6fDf51E38727907e43FC592aA827f;
    address constant validatorFeeRecipient =
        0xA7eA9Da13797F0965AD45CA25A3a19f9B85fb821;
    bool isFirstCommittee = false;

    function run() external {
        vm.startBroadcast();
        IWrap(wrap).addValidator(
            validator,
            isFirstCommittee,
            validatorFeeRecipient
        );
        vm.stopBroadcast();
    }
}
