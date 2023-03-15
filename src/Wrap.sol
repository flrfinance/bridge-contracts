// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {
    AccessControlEnumerable
} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IWrap } from "./interfaces/IWrap.sol";
import { Multisig } from "./libraries/Multisig.sol";

abstract contract Wrap is IWrap, AccessControlEnumerable {
    using Multisig for Multisig.DualMultisig;

    using SafeERC20 for IERC20;

    /// @dev The role ID for addresses that can pause the contract.
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE");

    /// @dev Max protocol/validator fee that can be set by the owner.
    uint16 constant maxFeeBPS = 500; // should be less than 10,000

    /// @dev True if the contracts are paused, false otherwise.
    bool public paused;

    /// @dev Map token address to token info.
    mapping(address => TokenInfoStore) public tokenInfos;

    /// @dev Map mirror token address to token address.
    mapping(address => address) public mirrorTokens;

    /// @dev Map validator to its fee recipient.
    mapping(address => address) public validatorFeeRecipients;

    /// @dev Array of all the tokens added.
    /// @notice A token in the list might not be active.
    address[] tokens;

    /// @dev Dual multisig to manage validators,
    /// attestations and request quorum.
    Multisig.DualMultisig internal multisig;

    /// @dev The number of deposits.
    uint256 public depositIndex;

    /// @dev Validator fee basis points.
    uint16 public validatorFeeBPS;

    constructor(Multisig.Config memory config, uint16 _validatorFeeBPS) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        multisig.configure(config);
        configureValidatorFees(_validatorFeeBPS);
    }

    /// @dev Hook to execute on deposit.
    /// @param token Address of the token being deposited.
    /// @param amount The amount being deposited.
    /// @return fee The fee charged to the depositor.
    function onDeposit(
        address token,
        uint256 amount
    ) internal virtual returns (uint256 fee);

    /// @dev Returns the fees charged for a given deposit amount.
    /// @param amount The deposit amount in question.
    /// @return fee The fee charged for the given deposit amount.
    function depositFees(
        uint256 amount
    ) internal view virtual returns (uint256 fee);

    /// @dev Hook to execute on successful bridging.
    /// @param token Address of the token being bridged.
    /// @param amount The amount being bridged.
    /// @param to The address where the bridged are being sent to.
    /// @return fee The fee charged to the user.
    function onExecute(
        address token,
        uint256 amount,
        address to
    ) internal virtual returns (uint256 fee);

    /// @inheritdoc IWrap
    function accumulatedValidatorFees(
        address token
    ) public view virtual returns (uint256 balance);

    /// @dev Modifier to make a function callable only when the contract is not paused.
    modifier isNotPaused() {
        if (paused == true) {
            revert ContractPaused();
        }
        _;
    }

    /// @dev Modifier to make a function callable only when the token and amount is correct.
    modifier isValidTokenAmount(address token, uint256 amount) {
        TokenInfoStore storage t = tokenInfos[token];

        // Notice that amount should be greater than minAmountWithFees.
        // This is required as amount after the fees should be greater
        // than minAmount so that when this is approved it passes the
        // isValidMirrorTokenAmount check.
        if (t.maxAmount <= amount || t.minAmountWithFees > amount) {
            revert InvalidTokenAmount();
        }

        if (t.dailyLimit != 0) {
            // Reset daily limit if the day is passed after last update.
            if (t.lastUpdated + 1 days > block.timestamp) {
                t.lastUpdated = block.timestamp;
                t.consumedLimit = 0;
            }

            if (t.consumedLimit + amount > t.dailyLimit) {
                revert DailyLimitExhausted();
            }
            t.consumedLimit += amount;
        }
        _;
    }

    /// @dev Modifier to make a function callable only when the token and amount is correct.
    modifier isValidMirrorTokenAmount(address mirrorToken, uint256 amount) {
        TokenInfoStore memory t = tokenInfos[mirrorTokens[mirrorToken]];
        if (t.maxAmount <= amount || t.minAmount > amount) {
            revert InvalidTokenAmount();
        }
        _;
    }

    /// @inheritdoc IWrap
    function nextExecutionIndex() external view returns (uint256) {
        return multisig.nextExecutionIndex;
    }

    /// @dev Internal function to calculate fees by amount and BPS.
    function calculateFee(
        uint256 amount,
        uint16 feeBPS
    ) internal pure returns (uint256) {
        // 10,000 is 100%
        return (amount * feeBPS) / 10000;
    }

    /// @inheritdoc IWrap
    function deposit(
        address token,
        uint256 amount,
        address to
    )
        external
        isNotPaused
        isValidTokenAmount(token, amount)
        returns (uint256 id)
    {
        if (to == address(0)) revert InvalidToAddress();
        id = depositIndex;
        depositIndex++;
        uint256 fee = onDeposit(token, amount);
        emit Deposit(id, token, amount - fee, to, fee);
    }

    /// @dev Internal function to calculate the hash of the request.
    function hashRequest(
        uint256 id,
        address token,
        uint256 amount,
        address to
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(id, token, amount, to));
    }

    /// @inheritdoc IWrap
    function approveExecute(
        uint256 id,
        address mirrorToken,
        uint256 amount,
        address to
    ) public isNotPaused isValidMirrorTokenAmount(mirrorToken, amount) {
        // If the request ID is lower than the last executed ID then simply ignore the request.
        if (id < multisig.nextExecutionIndex) {
            return;
        }

        bytes32 hash = hashRequest(id, mirrorToken, amount, to);
        Multisig.RequestStatusTransition transition = multisig.tryApprove(
            msg.sender,
            hash,
            id
        );
        if (transition == Multisig.RequestStatusTransition.NULLToUndecided) {
            emit Requested(id, mirrorToken, amount, to);
        }

        if (multisig.tryExecute(hash, id)) {
            address token = mirrorTokens[mirrorToken];
            uint256 fee = onExecute(token, amount, to);
            emit Executed(id, token, amount - fee, to, fee);
        }
    }

    /// @inheritdoc IWrap
    function batchApproveExecute(RequestInfo[] calldata requests) external {
        for (uint256 i = 0; i < requests.length; i++) {
            approveExecute(
                requests[i].id,
                requests[i].token,
                requests[i].amount,
                requests[i].to
            );
        }
    }

    function _configureTokenInfo(
        address token,
        uint256 minAmount,
        uint256 maxAmount,
        uint256 dailyLimit,
        bool newToken
    ) internal {
        uint256 currMinAmount = tokenInfos[token].minAmount;
        if (
            minAmount == 0 ||
            (newToken ? currMinAmount != 0 : currMinAmount == 0)
        ) {
            revert InvalidTokenConfig();
        }

        // configuring token also resets the daily volume limit
        TokenInfoStore memory tokenInfoStore = TokenInfoStore(
            maxAmount,
            minAmount,
            minAmount + depositFees(minAmount),
            dailyLimit,
            0,
            block.timestamp
        );
        tokenInfos[token] = tokenInfoStore;
    }

    /// @inheritdoc IWrap
    function configureToken(
        address token,
        TokenInfo calldata tokenInfo
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _configureTokenInfo(
            token,
            tokenInfo.minAmount,
            tokenInfo.maxAmount,
            tokenInfo.dailyLimit,
            false
        );
    }

    /// @inheritdoc IWrap
    function configureValidatorFees(
        uint16 _validatorFeeBPS
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_validatorFeeBPS > maxFeeBPS) {
            revert FeeExceedsMaxFee();
        }
        validatorFeeBPS = _validatorFeeBPS;
    }

    /// @dev Internal function to add a new token.
    /// @param token Token that will be deposited in the contract.
    /// @param mirrorToken Token that will be deposited in the mirror contract.
    /// @param tokenInfo Token info associated with the token.
    function _addToken(
        address token,
        address mirrorToken,
        TokenInfo calldata tokenInfo
    ) internal {
        if (mirrorTokens[mirrorToken] != address(0)) {
            revert InvalidTokenConfig();
        }

        _configureTokenInfo(
            token,
            tokenInfo.minAmount,
            tokenInfo.maxAmount,
            tokenInfo.dailyLimit,
            true
        );
        tokens.push(token);
        mirrorTokens[mirrorToken] = token;
    }

    /// @inheritdoc IWrap
    function configureMultisig(
        Multisig.Config calldata config
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        multisig.configure(config);
    }

    /// @inheritdoc IWrap
    function pause() external onlyRole(PAUSE_ROLE) {
        paused = true;
    }

    /// @inheritdoc IWrap
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        paused = false;
    }

    /// @inheritdoc IWrap
    function addValidator(
        address validator,
        bool isFirstCommittee,
        address feeRecipient
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        multisig.addSigner(validator, isFirstCommittee);
        validatorFeeRecipients[validator] = feeRecipient;
    }

    /// @inheritdoc IWrap
    function removeValidator(
        address validator
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        claimValidatorFees(validator);
        multisig.removeSigner(validator);
    }

    /// @inheritdoc IWrap
    function configureValidatorFeeRecipient(
        address validator,
        address feeRecipient
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        validatorFeeRecipients[validator] = feeRecipient;
    }

    /// @inheritdoc IWrap
    function claimValidatorFees(address validator) public {
        address feeRecipient = validatorFeeRecipients[validator];
        uint64 totalPoints = multisig.totalPoints;
        uint64 points = multisig.clearPoints(validator);
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 tokenValidatorFee = (accumulatedValidatorFees(token) *
                points) / totalPoints;
            IERC20(token).safeTransfer(feeRecipient, tokenValidatorFee);
        }
    }
}
