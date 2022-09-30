// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library Multisig {
    error SignerAlreadyExists(address signer);
    error SignerNotActive(address signer);
    error MaxCommitteeSizeReached();
    error RequestDecided(RequestStatus status);
    error SignerSigned();

    uint8 constant maxCommitteeSize = 128;
    uint16 constant maxSignersSize = 256; // maxCommitteeSize * 2

    enum RequestStatus {
        Undecided,
        Accepted,
        Rejected
    }

    enum SignerStatus {
        Uninitialized,
        Removed,
        FirstCommittee,
        SecondCommittee
    }

    struct Request {
        uint8 approvalsFirstCommittee;
        uint8 rejectionsFirstCommittee;
        uint8 approvalsSecondCommittee;
        uint8 rejectionsSecondCommittee;
        RequestStatus status;
        uint256 approvers;
        uint256 rejectors;
    }

    struct SignerInfo {
        SignerStatus status;
        uint8 index;
    }

    struct DualMultisig {
        uint8 firstCommitteeAcceptanceQuorum; // slot 1 (0 - 7bits)
        uint8 firstCommitteeRejectionQuorum; // slot 1 (8 - 15bits)
        uint8 secondCommitteeAcceptanceQuorum; // slot 1 (16 - 23bits)
        uint8 secondCommitteeRejectionQuorum; // slot 1 (24 - 31bits)
        uint8 firstCommitteeSize; // slot 1 (32 - 39bits)
        uint8 secondCommitteeSize; // slot 1 (40 - 47bits)
        uint64 totalPoints; // slot 1 (48 - 111 bits)
        // spare bits 112 - 144
        uint64[maxSignersSize] points;
        mapping(address => SignerInfo) signers;
        mapping(uint256 => Request) requests;
    }

    function addSigner(DualMultisig storage s, address signer, bool isFirstCommittee) internal {
        uint8 committeeSize = (isFirstCommittee ? s.firstCommitteeSize : s.secondCommitteeSize);
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

    function removeSigner(DualMultisig storage s, address signer) internal {
        SignerInfo storage signerInfo = s.signers[signer];
        if (signerInfo.status >= SignerStatus.FirstCommittee) {
            revert SignerNotActive(signer);
        }
        signerInfo.status = SignerStatus.Removed;
    }

    function incrementPoints(DualMultisig storage s, uint256 mask) private {
        uint8 count = 0;
        for (uint8 i = 0; i < maxSignersSize; i++) {
            if ((mask & (1 << i)) != 0) {
                s.points[i]++;
                count++;
            }
        }
        s.totalPoints += count;
    }

    function approve(DualMultisig storage s, address signer, uint256 id) internal returns (bool) {
        SignerInfo memory signerInfo = s.signers[signer];
        if (signerInfo.status >= SignerStatus.FirstCommittee) {
            revert SignerNotActive(signer);
        }
        Request storage request = s.requests[id];
        if (request.status != RequestStatus.Undecided) {
            revert RequestDecided(request.status);
        }
        uint256 signerMask = 1 << signerInfo.index;
        if ((signerMask & (request.approvers | request.rejectors)) != 0) {
            revert SignerSigned();
        }

        request.approvers |= signerMask;
        if (signerInfo.status == SignerStatus.FirstCommittee) {
            ++request.approvalsFirstCommittee;
        } else {
            ++request.approvalsSecondCommittee;
        }

        if (
            request.approvalsFirstCommittee >= s.firstCommitteeAcceptanceQuorum
                && request.approvalsSecondCommittee >= s.secondCommitteeAcceptanceQuorum
        ) {
            request.status = RequestStatus.Accepted;
            incrementPoints(s, request.approvers);
            return true;
        }
        return false;
    }

    function reject(DualMultisig storage s, address signer, uint256 id) internal returns (bool) {
        SignerInfo memory signerInfo = s.signers[signer];
        if (signerInfo.status >= SignerStatus.FirstCommittee) {
            revert SignerNotActive(signer);
        }
        Request storage request = s.requests[id];
        if (request.status != RequestStatus.Undecided) {
            revert RequestDecided(request.status);
        }
        uint256 signerMask = 1 << signerInfo.index;
        if ((signerMask & (request.approvers | request.rejectors)) != 0) {
            revert SignerSigned();
        }

        request.rejectors |= signerMask;
        bool rejectionQuorumReached;
        if (signerInfo.status == SignerStatus.FirstCommittee) {
            rejectionQuorumReached = (++request.rejectionsFirstCommittee) > s.firstCommitteeRejectionQuorum;
        } else {
            rejectionQuorumReached = (++request.rejectionsSecondCommittee) > s.secondCommitteeRejectionQuorum;
        }

        if (rejectionQuorumReached) {
            request.status = RequestStatus.Rejected;
            incrementPoints(s, request.rejectors);
            return true;
        }
        return false;
    }

    function clearPoints(DualMultisig storage s, address signer) internal {
        uint8 index = s.signers[signer].index;
        uint64 p = s.points[index];
        s.points[index] = 0;
        s.totalPoints -= p;
    }

    function status(DualMultisig storage s, uint256 id) internal view returns (RequestStatus) {
        return s.requests[id].status;
    }

    function totalPoints(DualMultisig storage s) internal view returns (uint64) {
        return s.totalPoints;
    }

    function points(DualMultisig storage s, address signer) internal view returns (uint64) {
        return s.points[s.signers[signer].index];
    }
}
