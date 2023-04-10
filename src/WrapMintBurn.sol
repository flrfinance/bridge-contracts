// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    IAccessControl
} from "@openzeppelin/contracts/access/IAccessControl.sol";

import { IWrap } from "./interfaces/IWrap.sol";
import { IWrapMintBurn } from "./interfaces/IWrapMintBurn.sol";
import { IERC20MintBurn } from "./interfaces/IERC20MintBurn.sol";
import { Multisig } from "./libraries/Multisig.sol";
import { Wrap } from "./Wrap.sol";
import { WrapToken } from "./WrapToken.sol";

contract WrapMintBurn is IWrapMintBurn, Wrap {
    using Multisig for Multisig.DualMultisig;

    using SafeERC20 for IERC20MintBurn;

    /// @dev Map token address to accumulated protocol fees.
    mapping(address => uint256) public accumulatedProtocolFees;

    /// @dev Protocol fee basis points charged on mint and burn.
    uint16 public protocolFeeBPS;

    // @dev Minter and Pauser roles for the Wraps token.
    bytes32 constant TOKEN_PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 constant TOKEN_MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(
        Multisig.Config memory config,
        uint16 _validatorFeeBPS,
        uint16 _protocolFeeBPS
    ) Wrap(config, _validatorFeeBPS) {
        configureProtocolFees(_protocolFeeBPS);
    }

    /// @inheritdoc Wrap
    function depositFees(
        uint256 amount
    ) internal view override returns (uint256 fee) {
        fee = calculateFee(amount, protocolFeeBPS);
    }

    /// @inheritdoc Wrap
    function onDeposit(
        address token,
        uint256 amount
    ) internal override returns (uint256 fee) {
        fee = depositFees(amount);
        accumulatedProtocolFees[token] += fee;

        IERC20MintBurn(token).burnFrom(msg.sender, amount - fee);
        IERC20MintBurn(token).transferFrom(msg.sender, address(this), fee);
    }

    /// @inheritdoc Wrap
    function onExecute(
        address token,
        uint256 amount,
        address to
    ) internal override returns (uint256 totalFee, uint256 validatorFee) {
        uint256 protocolFee = calculateFee(amount, protocolFeeBPS);
        accumulatedProtocolFees[token] += protocolFee;
        validatorFee = calculateFee(amount, validatorFeeBPS);
        totalFee = protocolFee + validatorFee;
        IERC20MintBurn(token).mint(to, amount - totalFee);
        IERC20MintBurn(token).mint(address(this), totalFee);
    }

    function onMigrate(address _newContract) internal override {
        // Transfer ownership of all the token contracts to the new address.
        // Unlike WrapDepositRedeem, this contract doesn't transfer the existing
        // validatorFee and protocolFee to the new contract. Therefore they can
        // still be claimed through this contract after the migration.
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            // Grant the new contracts all the roles.
            IAccessControl(token).grantRole(DEFAULT_ADMIN_ROLE, _newContract);
            IAccessControl(token).grantRole(TOKEN_MINTER_ROLE, _newContract);
            IAccessControl(token).grantRole(TOKEN_PAUSER_ROLE, _newContract);

            // Renounce all roles from the existing contract.
            IAccessControl(token).renounceRole(
                DEFAULT_ADMIN_ROLE,
                address(this)
            );
            IAccessControl(token).renounceRole(
                TOKEN_MINTER_ROLE,
                address(this)
            );
            IAccessControl(token).renounceRole(
                TOKEN_PAUSER_ROLE,
                address(this)
            );
        }
    }

    /// @inheritdoc IWrapMintBurn
    function configureProtocolFees(
        uint16 _protocolFeeBPS
    ) public onlyRole(WEAK_ADMIN_ROLE) {
        if (_protocolFeeBPS > maxFeeBPS) {
            revert FeeExceedsMaxFee();
        }
        protocolFeeBPS = _protocolFeeBPS;
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            TokenInfoStore memory tokenInfo = tokenInfos[token];
            _configureTokenInfo(
                token,
                tokenInfo.minAmount,
                tokenInfo.maxAmount,
                tokenInfo.dailyLimit,
                false
            );
        }
    }

    /// @inheritdoc IWrapMintBurn
    function createAddToken(
        string memory tokenName,
        string memory tokenSymbol,
        address existingToken,
        address mirrorToken,
        uint8 mirrorTokenDecimals,
        TokenInfo calldata tokenInfo
    ) external onlyRole(WEAK_ADMIN_ROLE) returns (address token) {
        token = existingToken == address(0)
            ? address(
                new WrapToken(tokenName, tokenSymbol, mirrorTokenDecimals)
            )
            : existingToken;
        _addToken(token, mirrorToken, tokenInfo);
    }

    /// @inheritdoc IWrapMintBurn
    function claimProtocolFees(
        address token,
        address recipient
    ) public onlyRole(WEAK_ADMIN_ROLE) {
        uint256 protocolFee = accumulatedProtocolFees[token];
        accumulatedProtocolFees[token] = 0;
        IERC20MintBurn(token).safeTransfer(recipient, protocolFee);
    }
}
