// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IWrapDepositRedeem } from "./interfaces/IWrapDepositRedeem.sol";
import { Multisig } from "./libraries/Multisig.sol";
import { Wrap } from "./Wrap.sol";

contract WrapDepositRedeem is IWrapDepositRedeem, Wrap {
    using Multisig for Multisig.DualMultisig;

    using SafeERC20 for IERC20;

    /// @dev max protocol/validator fee that can be set by the owner
    uint16 constant maxFeeBPS = 500;

    /// @dev validator fees basis points token on mint
    uint16 public validatorsFeeBPS;

    constructor(Multisig.Config memory config, uint16 _validatorsFeeBPS)
        Wrap(config)
    {
        configureFees(_validatorsFeeBPS);
    }

    /// @inheritdoc IWrapDepositRedeem
    function accumalatedValidatorsFees(address token)
        public
        view
        returns (uint256)
    {
        return IERC20(token).balanceOf(address(this));
    }

    function onDeposit(address token, uint256 amount)
        internal
        override
        returns (uint256)
    {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        return 0;
    }

    function onExecute(
        address token,
        uint256 amount,
        address to
    ) internal override returns (uint256 fee) {
        fee = calculateFee(amount, validatorsFeeBPS);
        IERC20(token).safeTransfer(to, amount);
    }

    /// @inheritdoc IWrapDepositRedeem
    function configureFees(uint16 _validatorsFeeBPS)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_validatorsFeeBPS > maxFeeBPS) {
            revert FeeExceedsMaxFee();
        }
        validatorsFeeBPS = _validatorsFeeBPS;
    }

    /// @inheritdoc IWrapDepositRedeem
    function addToken(
        address token,
        address mirrorToken,
        TokenInfo calldata tokenInfo
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _addToken(token, mirrorToken, tokenInfo);
    }

    /// @inheritdoc IWrapDepositRedeem
    function claimValidatorFees() public {
        uint64 points = multisig.clearPoints(msg.sender);
        uint64 totalPoints = multisig.totalPoints;
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 tokenValidatorFee = (accumalatedValidatorsFees(token) *
                points) / totalPoints;
            IERC20(token).safeTransfer(msg.sender, tokenValidatorFee);
        }
    }
}
