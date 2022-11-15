// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {
    AccessControlEnumerable
} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

import { IWrap } from "./interfaces/IWrap.sol";
import { Multisig } from "./libraries/Multisig.sol";

abstract contract Wrap is IWrap, AccessControlEnumerable {
    using Multisig for Multisig.DualMultisig;

    /// @dev the role id for addresses that
    /// can pause the contract
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE");

    /// @dev True if the contracts are paused,
    /// false otherwise.
    bool public paused;

    /// @dev Map tokenAddress to tokenInfo
    mapping(address => TokenInfo) public tokenInfos;

    /// @dev Map mirrorToken to token
    mapping(address => address) public mirrorTokens;

    /// @dev Array of all the tokens added
    /// @notice a token in the list might not be active
    address[] tokens;

    /// @dev dual multisig to manage signers,
    /// attestations and request quoroum.
    Multisig.DualMultisig internal multisig;

    /// @dev the number of deposits.
    uint256 public depositIndex;

    constructor(Multisig.Config memory config) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        multisig.configure(config);
    }

    function onDeposit(address token, uint256 amount)
        internal
        virtual
        returns (uint256 fee);

    function onExecute(
        address token,
        uint256 amount,
        address to
    ) internal virtual returns (uint256 fee);

    /// @dev Modifier to make a function callable only when the contract is not paused.
    modifier isNotPaused() {
        if (paused == true) {
            revert ContractPaused();
        }
        _;
    }

    /// @dev Modifier to make a function callable only when the token and amount is correct.
    modifier isValidTokenAmount(address token, uint256 amount) {
        TokenInfo memory t = tokenInfos[token];
        if (t.maxAmount <= amount || t.minAmount > amount) {
            revert InvalidTokenAmount();
        }
        _;
    }

    /// @dev Modifier to make a function callable only when the token and amount is correct.
    modifier isValidMirrorTokenAmount(address mirrorToken, uint256 amount) {
        TokenInfo memory t = tokenInfos[mirrorTokens[mirrorToken]];
        if (t.maxAmount <= amount || t.minAmount > amount) {
            revert InvalidTokenAmount();
        }
        _;
    }

    /// @inheritdoc IWrap
    function nextExecutionIndex() external view returns (uint256) {
        return multisig.nextExecutionIndex;
    }

    /// @dev Internal function to calculate fees
    function calculateFee(uint256 amount, uint16 feeBPS)
        internal
        pure
        returns (uint256)
    {
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
        address _to = to == address(0) ? msg.sender : to;
        id = depositIndex;
        depositIndex++;
        uint256 fee = onDeposit(token, amount);
        emit Deposit(id, token, amount - fee, _to, fee);
    }

    /// @dev internal function to calculate the hash of the request.
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
        // if the request id is lower than the last executed id then simply ignore the request
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
            emit Executed(id, token, amount, to, fee);
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

    /// @inheritdoc IWrap
    function configureToken(address token, TokenInfo calldata tokenInfo)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (tokenInfo.minAmount == 0 || tokenInfos[token].minAmount == 0) {
            revert InvalidTokenConfig();
        }
        tokenInfos[token] = tokenInfo;
    }

    /// @dev internal function to add new token.
    /// @param token token that will be deposited in the contract.
    /// @param mirrorToken token that will be deposited in the mirror contract.
    /// @param tokenInfo token info associated to the token.
    function _addToken(
        address token,
        address mirrorToken,
        TokenInfo calldata tokenInfo
    ) internal {
        TokenInfo memory ti = tokenInfos[token];
        if (
            tokenInfo.minAmount == 0 ||
            ti.minAmount != 0 ||
            mirrorTokens[mirrorToken] != address(0)
        ) {
            revert InvalidTokenConfig();
        }
        tokens.push(token);
        tokenInfos[token] = tokenInfo;
        mirrorTokens[mirrorToken] = token;
    }

    /// @inheritdoc IWrap
    function configureMultisig(Multisig.Config calldata config)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
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
    function addSigner(address signer, bool isFirstCommittee)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        multisig.addSigner(signer, isFirstCommittee);
    }

    /// @inheritdoc IWrap
    function removeSigner(address signer)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        multisig.removeSigner(signer);
    }
}
