// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

/// @title Two committee multisig library.
/// @dev Implements a multisig with two committees.
/// A separate quorum must be reached in both committees
/// to approve a given request. A request is rejected if
/// either of the two committees rejects it. Each committee
/// cannot have more than 128 members. For every quorum, the
/// signer that attested in favor of the corresponding request
/// is rewarded a point. The intention is to use the accumulated
/// points to appropriately reward signers for their good deeds.
library Multisig {
    /// @dev Thrown when an already existing signer is added.
    error SignerAlreadyExists(address signer);

    /// @dev Thrown when an account that is performing some
    /// signer-only action is not an active signer.
    error SignerNotActive(address signer);

    /// @dev Thrown when attempting to add a new signer
    /// after the max committee size has been reached.
    error MaxCommitteeSizeReached();

    /// @dev Thrown when the configuration parmeters that are
    /// being set are not valid.
    error InvalidConfiguration();

    /// @dev Thrown when a given ID has already been assigned
    /// to an apprroved request.
    error InvalidId();

    /// @dev Thrown when an execution attempt is made for a
    /// request that is too far in the future or has not been
    /// approved yet.
    error InvalidExecuteRequest();

    /// @dev Maximum number of members in each committee.
    /// @notice This number cannot be increased further
    /// with the current implementation. Our implementation
    /// uses bitmasks and the uint8 data type to optimize gas.
    /// These data structures will overflow if maxCommitteeSize
    /// is greater than 128.
    uint8 constant maxCommitteeSize = 128;

    /// @dev Maximum number of members in both committees
    /// combined.
    /// @notice Similarly to maxCommitteeSize, maxSignersSize
    /// also cannot be further increased to more than 256.
    uint16 constant maxSignersSize = 256; // maxCommitteeSize * 2

    /// @dev Request statuses.
    enum RequestStatus {
        NULL, // request which doesn't exist
        Undecided, // request hasn't reached quorum
        Accepted // request has been approved
    }

    enum RequestStatusTransition {
        Unchanged,
        NULLToUndecided,
        UndecidedToAccepted
    }

    /// @dev Signer statuses.
    enum SignerStatus {
        Uninitialized,
        Removed,
        FirstCommittee,
        SecondCommittee
    }

    /// @dev Request info.
    /// @param approvalsFirstCommittee Number of approvals
    /// by the first committee.
    /// @param approvalsSecondCommittee Number of approvals
    /// by the second committee.
    /// @param status Status of the request.
    /// @param approvers Bitmask for signers from the two
    /// committees who have accepted the request.
    /// @notice Approvers is a bitmask. For example, a set bit at
    /// position 2 in the approvers bitmask indicates that the
    /// signer with index 2 has approved the request.
    struct Request {
        uint8 approvalsFirstCommittee; // slot 1 (0 - 7 bits)
        uint8 approvalsSecondCommittee; // slot 1 (8 - 15 bits)
        RequestStatus status; // slot 1 (16 - 23 bits)
        // slot 1 (23 - 255 spare bits)
        uint256 approvers; // slot 2
    }

    /// @dev Signer information.
    /// @param status Status of the signer.
    /// @param index Index of the signer.
    struct SignerInfo {
        SignerStatus status;
        uint8 index;
    }

    /// @dev DualMultisig
    /// @param firstCommitteeAcceptanceQuorum Number of acceptances
    /// required to reach quorum in the first committee.
    /// @param secondCommitteeAcceptanceQuorum Number of acceptances
    /// required to reach quorum in the second committee.
    /// @param firstCommitteeSize Size of the first committee.
    /// @param secondCommitteeSize Size of the second committee.
    /// @param totalPoints Total points accumulated among all signers.
    /// @param nextExecutionIndex Index of the request that will be executed next.
    /// @param points An array of points where element i is the points
    /// accumulated by signer at index i.
    /// @param signers Mapping from signer address to signer info.
    /// @param requests Mapping from request hash to request info.
    /// @param approvedRequests Mapping request ID to request hash.
    struct DualMultisig {
        uint8 firstCommitteeAcceptanceQuorum; // slot 1 (0 - 7bits)
        uint8 secondCommitteeAcceptanceQuorum; // slot 1 (8 - 15bits)
        uint8 firstCommitteeSize; // slot 1 (16 - 23bits)
        uint8 secondCommitteeSize; // slot 1 (24 - 31bits)
        uint64 totalPoints; // slot 1 (32 - 95 bits)
        // slot1 (95 - 255 spare bits)
        uint256 nextExecutionIndex;
        uint64[maxSignersSize] points;
        mapping(address => SignerInfo) signers;
        mapping(bytes32 => Request) requests;
        mapping(uint256 => bytes32) approvedRequests;
    }

    /// @param firstCommitteeAcceptanceQuorum Number of acceptances
    /// required to reach quorum in the first committee.
    /// @param secondCommitteeAcceptanceQuorum Number of acceptances
    /// required to reach quorum in the second committee.
    /// @notice Both acceptance quorums should be greater than zero
    /// and less than or equal to maxCommitteeSize.
    struct Config {
        uint8 firstCommitteeAcceptanceQuorum;
        uint8 secondCommitteeAcceptanceQuorum;
    }

    /// @dev Returns a request status for a given request hash.
    /// @param s The relevant multisig to check.
    /// @param hash The hash of the request being checked.
    /// @return The status of the request with the given hash.
    function status(
        DualMultisig storage s,
        bytes32 hash
    ) internal view returns (RequestStatus) {
        return s.requests[hash].status;
    }

    /// @dev Returns whether or not a given address is a signer
    /// in the multisig.
    /// @param s The relevant multisig to check.
    /// @param signer The address of the potential signer.
    /// @return True if the provided address is a signer.
    function isSigner(
        DualMultisig storage s,
        address signer
    ) internal view returns (bool) {
        return s.signers[signer].status >= SignerStatus.FirstCommittee;
    }

    /// @dev Returns the number of points accumulated by a
    /// given signer.
    /// @param s The relevant multisig to check.
    /// @param signer The address of the signer.
    /// @return The number of points accumalted by the
    /// given signer.
    function points(
        DualMultisig storage s,
        address signer
    ) internal view returns (uint64) {
        SignerInfo memory signerInfo = s.signers[signer];
        if (signerInfo.status < SignerStatus.FirstCommittee) {
            revert SignerNotActive(signer);
        }
        return s.points[signerInfo.index];
    }

    /// @dev Updates a multisig's configuration.
    function configure(DualMultisig storage s, Config memory c) internal {
        if (
            c.firstCommitteeAcceptanceQuorum == 0 ||
            c.firstCommitteeAcceptanceQuorum > maxCommitteeSize ||
            c.secondCommitteeAcceptanceQuorum == 0 ||
            c.secondCommitteeAcceptanceQuorum > maxCommitteeSize
        ) {
            revert InvalidConfiguration();
        }
        s.firstCommitteeAcceptanceQuorum = c.firstCommitteeAcceptanceQuorum;
        s.secondCommitteeAcceptanceQuorum = c.secondCommitteeAcceptanceQuorum;
    }

    /// @dev Adds a new signer.
    /// @param s The multisig to add the signer to.
    /// @param signer The address of the signer to add.
    /// @param isFirstCommittee True if the signer is to be
    /// added to the first committee and false if they are
    /// to be added to the second committee.
    function addSigner(
        DualMultisig storage s,
        address signer,
        bool isFirstCommittee
    ) internal {
        uint8 committeeSize = (
            isFirstCommittee ? s.firstCommitteeSize : s.secondCommitteeSize
        );
        if (committeeSize == maxCommitteeSize) {
            revert MaxCommitteeSizeReached();
        }

        SignerInfo storage signerInfo = s.signers[signer];
        if (signerInfo.status != SignerStatus.Uninitialized) {
            revert SignerAlreadyExists(signer);
        }

        if (isFirstCommittee) {
            s.firstCommitteeSize++;
            signerInfo.status = SignerStatus.FirstCommittee;
        } else {
            s.secondCommitteeSize++;
            signerInfo.status = SignerStatus.SecondCommittee;
        }

        signerInfo.index = s.firstCommitteeSize + s.secondCommitteeSize;
    }

    /// @dev Removes a signer.
    /// @param s The multisig to remove the signer from.
    /// @param signer The signer to be removed.
    function removeSigner(DualMultisig storage s, address signer) internal {
        SignerInfo storage signerInfo = s.signers[signer];
        if (signerInfo.status < SignerStatus.FirstCommittee) {
            revert SignerNotActive(signer);
        }
        signerInfo.status = SignerStatus.Removed;
    }

    /// @dev Helper function to increment signer points as per a mask.
    /// @param s The multisig for which to increment the signer points.
    /// @param mask The bit mask to use for incrementing the points.
    /// @notice A set bit at index i in the mask should increment the
    /// number of points of the signer at index i by one.
    function incrementPoints(DualMultisig storage s, uint256 mask) private {
        uint16 count = 0;
        for (uint16 i = 0; i < maxSignersSize; i++) {
            if ((mask & (1 << i)) != 0) {
                s.points[i]++;
                count++;
            }
        }
        s.totalPoints += count;
    }

    /// @dev Approve a request if its has not already been approved.
    /// @param s The multisig for which to approve the given request.
    /// @param signer The signer approving the request.
    /// @param hash The hash of the request being approved.
    /// @return The request's status transition.
    /// @dev Notice that this code assumes that the hash is generated from
    /// the ID and other data outside of this function. It is important to include
    /// the ID in the hash.
    function tryApprove(
        DualMultisig storage s,
        address signer,
        bytes32 hash,
        uint256 id
    ) internal returns (RequestStatusTransition) {
        Request storage request = s.requests[hash];
        // If the request has already been accepted
        // then simply return.
        if (request.status == RequestStatus.Accepted) {
            return RequestStatusTransition.Unchanged;
        }

        SignerInfo memory signerInfo = s.signers[signer];
        // Make sure that the signer is valid.
        if (signerInfo.status < SignerStatus.FirstCommittee) {
            revert SignerNotActive(signer);
        }

        // Revert if another request with the same ID has
        // already been approved.
        if (s.approvedRequests[id] != bytes32(0)) {
            revert InvalidId();
        }

        uint256 signerMask = 1 << signerInfo.index;
        // Check if the signer has already signed.
        if ((signerMask & request.approvers) != 0) {
            return RequestStatusTransition.Unchanged;
        }

        // Add the signer to the bitmask of approvers.
        request.approvers |= signerMask;
        if (signerInfo.status == SignerStatus.FirstCommittee) {
            ++request.approvalsFirstCommittee;
        } else {
            ++request.approvalsSecondCommittee;
        }

        // If quorum has been reached, increment the number of points.
        if (
            request.approvalsFirstCommittee >=
            s.firstCommitteeAcceptanceQuorum &&
            request.approvalsSecondCommittee >=
            s.secondCommitteeAcceptanceQuorum
        ) {
            request.status = RequestStatus.Accepted;
            s.approvedRequests[id] = hash;
            incrementPoints(s, request.approvers);
            return RequestStatusTransition.UndecidedToAccepted;
        } else if (request.status == RequestStatus.NULL) {
            // If this is the first approval, change the request status
            // to undecided.
            request.status = RequestStatus.Undecided;
            return RequestStatusTransition.NULLToUndecided;
        }
        return RequestStatusTransition.Unchanged;
    }

    /// @dev Try to execute the next approved request.
    /// @param s The multisig whose next request should
    /// be executed.
    /// @param hash The hash of the request being executed.
    /// @param id The ID of the request being executed.
    /// @return True if the execution was successful.
    function tryExecute(
        DualMultisig storage s,
        bytes32 hash,
        uint256 id
    ) internal returns (bool) {
        if (id == s.nextExecutionIndex && s.approvedRequests[id] == hash) {
            s.nextExecutionIndex++;
            return true;
        }
        return false;
    }

    /// @dev Clears the points accumulated by a signer.
    /// @param s The multisig for which to clear the given signer's points.
    /// @param signer The address of the signer whose points to clear.
    /// @return The number of points that were cleared.
    function clearPoints(
        DualMultisig storage s,
        address signer
    ) internal returns (uint64) {
        SignerInfo memory signerInfo = s.signers[signer];
        if (signerInfo.status < SignerStatus.FirstCommittee) {
            revert SignerNotActive(signer);
        }
        uint8 index = signerInfo.index;
        uint64 p = s.points[index];
        s.points[index] = 0;
        s.totalPoints -= p;
        return p;
    }
}
