// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/interfaces/IWrap.sol";

contract ConfigureToken is Script {
    // address constant wrap = 0x9550c9651b681Ce9FE1f3D8c416F785e6350274c;
    address constant wrap = 0x9550c9651b681Ce9FE1f3D8c416F785e6350274c;
    address constant token = 0x767F3AB8900d8011856F18Da0Bf7cD46E85a429F;
    uint256 constant minAmount = 1e17;
    uint256 constant maxAmount = 1e24;

    function run() external {
        IWrap.TokenInfo memory ti = IWrap.TokenInfo({
            maxAmount: maxAmount,
            minAmount: minAmount
        });

        vm.startBroadcast();
        IWrap(wrap).configureToken(token, ti);
        vm.stopBroadcast();
    }
}
