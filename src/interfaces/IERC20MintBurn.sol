// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20MintBurn is IERC20 {
    /// @dev mints token to the holder.
    /// @param holder address to mint the tokens.
    /// @param amount amount of tokens to mint.
    function mint(address holder, uint256 amount) external;

    /// @dev burns token of the holder.
    /// @param holder address to burn the tokens from.
    /// @param amount amount of tokens to burn.
    function burnFrom(address holder, uint256 amount) external;
}
