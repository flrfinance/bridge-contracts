// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract WrapToken is ERC20PresetMinterPauser {
    uint8 immutable _decimals;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20PresetMinterPauser(name_, symbol_) {
        _decimals = decimals_;
    }

    /// @dev The number of decimals used to get the token's
    /// user representation.
    /// @return The number of decimals.
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}
