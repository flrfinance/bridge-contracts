// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { WrapToken } from "../src/WrapToken.sol";
import { TestAsserter } from "./utils/TestAsserter.sol";

contract WrapTokenTest is TestAsserter {
    string name = "TestToken";
    string symbol = "TT";
    uint8 decimals = 18;

    WrapToken token;

    constructor() {
        token = new WrapToken(name, symbol, decimals);
    }

    function testName() public {
        assertEq(token.name(), name);
    }

    function testSymbol() public {
        assertEq(token.symbol(), symbol);
    }

    function testDecimals() public {
        assertEq(token.decimals(), decimals);
    }
}
