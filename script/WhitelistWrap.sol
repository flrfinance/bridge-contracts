// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/interfaces/IWrapMintBurn.sol";
import "../src/interfaces/IWrapDepositRedeem.sol";
import "./utils/Constants.sol";

contract WhitelistWrap is Script, Constants {
    // First run in COSTON and then in APOTHEM

    //address constant wrap = APOTHEM;
    address constant wrap = COSTON;

    address constant token = WXDC_APOTHEM; // run in APOTHEM

    //address constant mirrorToken = WXDC_COSTON; // run in APOTHEM
    address constant mirrorToken = WXDC_APOTHEM; // run in COSTON

    //bool constant isWrapMintBurn = false; // run in APOTHEM
    bool constant isWrapMintBurn = true; // run in COSTON

    string constant tokenName = "Wrapped XDC";
    string constant tokenSymbol = "WXDC";
    uint256 constant minAmount = 1e18;
    uint256 constant maxAmount = 1e21;
    uint256 constant dailyLimit = 1e24;

    function run() external {
        IWrap.TokenInfo memory ti = IWrap.TokenInfo(
            maxAmount,
            minAmount,
            dailyLimit
        );

        vm.startBroadcast();
        if (isWrapMintBurn) {
            address wrapToken = IWrapMintBurn(wrap).createAddToken(
                tokenName,
                tokenSymbol,
                mirrorToken,
                18,
                ti
            );
            console.log(wrapToken);
        } else {
            IWrapDepositRedeem(wrap).addToken(token, mirrorToken, ti);
        }
        vm.stopBroadcast();
    }
}
