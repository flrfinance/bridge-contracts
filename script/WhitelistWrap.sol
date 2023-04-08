// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/interfaces/IWrapMintBurn.sol";
import "../src/interfaces/IWrapDepositRedeem.sol";

contract WhitelistWrap is Script {
    address constant wrap = 0x9550c9651b681Ce9FE1f3D8c416F785e6350274c;
    address constant token = 0xE99500AB4A413164DA49Af83B9824749059b46ce;
    address constant mirrorToken = 0x767F3AB8900d8011856F18Da0Bf7cD46E85a429F;
    string constant tokenName = "Wrapped XDC";
    string constant tokenSymbol = "WXDC";
    uint256 constant minAmount = 1e18;
    uint256 constant maxAmount = 1e24;
    uint256 constant dailyLimit = 1e20;
    bool constant isWrapMintBurn = false;
    bool constant isExistingToken = false;

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
                isExistingToken ? token : address(0),
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
