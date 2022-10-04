// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IWrapMintBurn} from "./interfaces/IWrapMintBurn.sol";
import {IERC20MintBurn} from "./interfaces/IERC20MintBurn.sol";
import {Multisig} from "./libraries/Multisig.sol";
import {Wrap} from "./wrap.sol";

contract WrapMintBurn is IWrapMintBurn, Wrap {
    using Multisig for Multisig.DualMultisig;

    using SafeERC20 for IERC20MintBurn;

    /// @dev max protocol/validator fee that can be set by the owner 
    uint16 constant maxFeeBPS = 500;

    /// @dev mapping to keep track of protocol fees accumalated per token
    mapping(address => uint256) public accumalatedProtocolFees;

    /// @dev protocol fees basis point taken on mint and burn
    uint16 public protocolFeeBPS;

    /// @dev validator fees basis points token on mint 
    uint16 public validatorsFeeBPS;

    constructor(
        Multisig.Config memory config,
        uint16 _protocolFeeBPS,
        uint16 _validatorsFeeBPS
    ) Wrap(config) {
        configureFees(_protocolFeeBPS, _validatorsFeeBPS);
    }

    /// @inheritdoc IWrapMintBurn
    function accumalatedValidatorsFees(address token) public view returns (uint256) {
        return IERC20MintBurn(token).balanceOf(address(this)) - accumalatedProtocolFees[token];
    }

    function onDeposit(uint256, address token, uint256 amount, address)
        internal
        override
        returns (uint256 depositAmount)
    {
        uint256 protocolFee = calculateFee(amount, protocolFeeBPS);
        accumalatedProtocolFees[token] += protocolFee;
        depositAmount = amount - protocolFee;

        IERC20MintBurn(token).burn(msg.sender, depositAmount);
        IERC20MintBurn(token).transferFrom(msg.sender, address(this), protocolFee);
    }

    function onApprove(uint256, address token, uint256 amount, address to) internal override {
        uint256 protocolFee = calculateFee(amount, protocolFeeBPS);
        accumalatedProtocolFees[token] += protocolFee;
        uint256 totalFee = protocolFee + calculateFee(amount, validatorsFeeBPS);

        IERC20MintBurn(token).mint(to, amount - totalFee);
        IERC20MintBurn(token).mint(address(this), totalFee);
    }

    /// @inheritdoc IWrapMintBurn
    function configureFees(uint16 _protocolFeeBPS, uint16 _validatorsFeeBPS) public {
        if (_protocolFeeBPS > maxFeeBPS || _validatorsFeeBPS > maxFeeBPS) 
            revert FeeExceedsMaxFee();
        protocolFeeBPS = _protocolFeeBPS;
        validatorsFeeBPS = _validatorsFeeBPS;
    }

    /// @inheritdoc IWrapMintBurn
    function claimValidatorFees() public {
        uint64 points = multisig.clearPoints(msg.sender);
        uint64 totalPoints = multisig.totalPoints;
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 tokenValidatorFee = (accumalatedValidatorsFees(token) * points) / totalPoints;
            IERC20MintBurn(token).safeTransfer(msg.sender, tokenValidatorFee);
        }
    }

    /// @inheritdoc IWrapMintBurn
    function claimProtocolFees(address token) public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 protocolFee = accumalatedProtocolFees[token];
        accumalatedProtocolFees[token] = 0;
        IERC20MintBurn(token).safeTransfer(msg.sender, protocolFee);
    }
}
