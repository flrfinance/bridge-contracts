// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

/**
 * Copyright (C) 2023 Flare Finance B.V. - All Rights Reserved.
 *
 * This source code and any functionality deriving from it are owned by Flare
 * Finance BV and the use of it is only permitted within the official platforms
 * and/or original products of Flare Finance B.V. and its licensed parties. Any
 * further enquiries regarding this copyright and possible licenses can be directed
 * to partners[at]flr.finance.
 *
 * The source code and any functionality deriving from it are provided "as is",
 * without warranty of any kind, express or implied, including but not limited to
 * the warranties of merchantability, fitness for a particular purpose and
 * noninfringement. In no event shall the authors or copyright holder be liable
 * for any claim, damages or other liability, whether in an action of contract,
 * tort or otherwise, arising in any way out of the use or other dealings or in
 * connection with the source code and any functionality deriving from it.
 */

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
