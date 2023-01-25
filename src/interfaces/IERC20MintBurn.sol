// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20MintBurn is IERC20 {
    /// @dev Mints tokens to the given holder.
    /// @param holder Address to mint the tokens to.
    /// @param amount Amount of tokens to mint.
    function mint(address holder, uint256 amount) external;

    /// @dev Burns tokens on the given holder's account.
    /// @param holder Address of the account whose tokens to burn.
    /// @param amount Amount of tokens to burn.
    function burnFrom(address holder, uint256 amount) external;
}
