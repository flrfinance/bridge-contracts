// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/interfaces/IWrap.sol";
import "./utils/Constants.sol";

contract ConfigureToken is Script, Constants {
    address constant wrap = APOTHEM;
    //address constant wrap = COSTON;

    address constant token = WXDC_APOTHEM;
    //address constant token = WXDC_COSTON;

    uint256 constant minAmount = 1e18;
    uint256 constant maxAmount = 1e24;
    uint256 constant dailyLimit = 1e20;

    function run() external {
        IWrap.TokenInfo memory ti = IWrap.TokenInfo({
            maxAmount: maxAmount,
            minAmount: minAmount,
            dailyLimit: dailyLimit
        });

        vm.startBroadcast();
        IWrap(wrap).configureToken(token, ti);
        vm.stopBroadcast();
    }
}
