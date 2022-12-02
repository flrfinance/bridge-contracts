// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IWrapMintBurn } from "./interfaces/IWrapMintBurn.sol";
import { IERC20MintBurn } from "./interfaces/IERC20MintBurn.sol";
import { Multisig } from "./libraries/Multisig.sol";
import { Wrap } from "./Wrap.sol";
import { WrapToken } from "./WrapToken.sol";

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
    function accumalatedValidatorsFees(address token)
        public
        view
        returns (uint256)
    {
        return
            IERC20MintBurn(token).balanceOf(address(this)) -
            accumalatedProtocolFees[token];
    }

    function depositFees(uint256 amount)
        internal
        view
        override
        returns (uint256 fee)
    {
        fee = calculateFee(amount, protocolFeeBPS);
    }

    function onDeposit(address token, uint256 amount)
        internal
        override
        returns (uint256 fee)
    {
        fee = depositFees(amount);
        accumalatedProtocolFees[token] += fee;

        IERC20MintBurn(token).burnFrom(msg.sender, amount - fee);
        IERC20MintBurn(token).transferFrom(msg.sender, address(this), fee);
    }

    function executeFees(uint256 amount)
        internal
        view
        override
        returns (uint256 fee)
    {
        fee = calculateFee(amount, validatorsFeeBPS + protocolFeeBPS);
    }

    function onExecute(
        address token,
        uint256 amount,
        address to
    ) internal override returns (uint256 fee) {
        uint256 protocolFee = calculateFee(amount, protocolFeeBPS);
        accumalatedProtocolFees[token] += protocolFee;
        fee = protocolFee + calculateFee(amount, validatorsFeeBPS);

        IERC20MintBurn(token).mint(to, amount - fee);
        IERC20MintBurn(token).mint(address(this), fee);
    }

    /// @inheritdoc IWrapMintBurn
    function configureFees(uint16 _protocolFeeBPS, uint16 _validatorsFeeBPS)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_protocolFeeBPS > maxFeeBPS || _validatorsFeeBPS > maxFeeBPS) {
            revert FeeExceedsMaxFee();
        }
        protocolFeeBPS = _protocolFeeBPS;
        validatorsFeeBPS = _validatorsFeeBPS;
    }

    function createAddToken(
        string memory tokenName,
        string memory tokenSymbol,
        address mirrorToken,
        uint8 mirrorTokenDecimals,
        TokenInfo calldata tokenInfo
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (address token) {
        token = address(
            new WrapToken(tokenName, tokenSymbol, mirrorTokenDecimals)
        );
        _addToken(token, mirrorToken, tokenInfo);
        return token;
    }

    /// @inheritdoc IWrapMintBurn
    function claimValidatorFees() public {
        uint64 points = multisig.clearPoints(msg.sender);
        uint64 totalPoints = multisig.totalPoints;
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 tokenValidatorFee = (accumalatedValidatorsFees(token) *
                points) / totalPoints;
            IERC20MintBurn(token).safeTransfer(msg.sender, tokenValidatorFee);
        }
    }

    /// @inheritdoc IWrapMintBurn
    function claimProtocolFees(address token)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        uint256 protocolFee = accumalatedProtocolFees[token];
        accumalatedProtocolFees[token] = 0;
        IERC20MintBurn(token).safeTransfer(msg.sender, protocolFee);
    }
}
