// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/interfaces/IWrapMintBurn.sol";
import "./utils/Constants.sol";

contract ConfigureProtocolFees is Script, Constants {
    address constant wrap = COSTON;

    function run() external {
        vm.startBroadcast();
        IWrapMintBurn(wrap).configureProtocolFees(PROTOCOL_FEES);
        vm.stopBroadcast();
    }
}
