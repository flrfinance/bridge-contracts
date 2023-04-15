// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "../src/interfaces/IWrap.sol";
import "./utils/Constants.sol";

contract AddPauser is Script, Constants {
    address constant wrap = APOTHEM;
    //address constant wrap = COSTON;

    address constant pauser = 0xaef52Ba3119eE28695E5AaA0788F11015E1DaD46;
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE");

    function run() external {
        vm.startBroadcast();
        IWrap(wrap).grantRole(PAUSE_ROLE, pauser);
        vm.stopBroadcast();
    }
}
