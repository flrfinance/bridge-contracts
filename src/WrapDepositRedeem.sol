// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IWrap } from "./interfaces/IWrap.sol";
import { IWrapDepositRedeem } from "./interfaces/IWrapDepositRedeem.sol";
import { Multisig } from "./libraries/Multisig.sol";
import { Wrap } from "./Wrap.sol";

contract WrapDepositRedeem is IWrapDepositRedeem, Wrap {
    using Multisig for Multisig.DualMultisig;

    using SafeERC20 for IERC20;

    constructor(Multisig.Config memory config, uint16 _validatorFeeBPS)
        Wrap(config, _validatorFeeBPS)
    {}

    /// @inheritdoc IWrap
    function accumulatedValidatorFees(address token)
        public
        view
        virtual
        override(IWrap, Wrap)
        returns (uint256)
    {
        return IERC20(token).balanceOf(address(this));
    }

    /// @inheritdoc Wrap
    function depositFees(uint256) internal pure override returns (uint256 fee) {
        return 0;
    }

    /// @inheritdoc Wrap
    function onDeposit(address token, uint256 amount)
        internal
        virtual
        override
        returns (uint256)
    {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        return depositFees(amount);
    }

    /// @inheritdoc Wrap
    function onExecute(
        address token,
        uint256 amount,
        address to
    ) internal virtual override returns (uint256 fee) {
        fee = calculateFee(amount, validatorFeeBPS);
        IERC20(token).safeTransfer(to, amount - fee);
    }

    /// @inheritdoc IWrapDepositRedeem
    function addToken(
        address token,
        address mirrorToken,
        TokenInfo calldata tokenInfo
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _addToken(token, mirrorToken, tokenInfo);
    }
}
