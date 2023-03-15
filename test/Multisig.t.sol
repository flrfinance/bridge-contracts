// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { TestAsserter } from "./utils/TestAsserter.sol";
import { Multisig } from "../src/libraries/Multisig.sol";
import { MultisigHelpers } from "./utils/MultisigHelpers.sol";
import "forge-std/console.sol";

contract MultisigTest is TestAsserter, MultisigHelpers {
    using Multisig for Multisig.DualMultisig;

    Multisig.DualMultisig multisig;

    struct RequestParams {
        uint256 id;
        uint256 message;
    }

    struct Request {
        RequestParams params;
        bytes32 hash;
    }

    address currentSigner;
    address signerInFirstCommittee;
    address signerInSecondCommittee;

    RequestParams testRequestParams;

    Request currentRequest;

    function _addSigner(Committee committee) internal {
        currentSigner = signer;
        multisig.addSigner(
            currentSigner,
            committee == Committee.First ? true : false
        );
    }

    modifier withSigner(Committee committee) {
        _addSigner(committee);
        _;
    }

    modifier withAnySigner() {
        _addSigner(block.number % 2 == 0 ? Committee.First : Committee.Second);
        _;
    }

    modifier withSignersFromBothCommittees() {
        signerInFirstCommittee = signerA;
        signerInSecondCommittee = signerB;

        if (!multisig.isSigner(signerInFirstCommittee)) {
            multisig.addSigner(signerInFirstCommittee, true);
        }

        if (!multisig.isSigner(signerInSecondCommittee)) {
            multisig.addSigner(signerInSecondCommittee, false);
        }

        _;
    }

    function _craftRequest(RequestParams memory requestParams) internal {
        bytes32 hash = keccak256(
            abi.encodePacked(requestParams.id, requestParams.message)
        );
        currentRequest = Request({ params: requestParams, hash: hash });
    }

    modifier withRequest() {
        _craftRequest(testRequestParams);
        _;
    }

    modifier withCustomRequest(RequestParams memory requestParams) {
        _craftRequest(requestParams);
        _;
    }

    function _craftUndecidedRequest(
        RequestParams memory requestParams
    ) internal withCustomRequest(requestParams) withAnySigner {
        multisig.tryApprove(signer, currentRequest.hash, requestParams.id);
    }

    modifier withUndecidedRequest() {
        _craftUndecidedRequest(testRequestParams);
        _;
    }

    function _craftApprovedRequest(
        RequestParams memory requestParams
    ) internal withCustomRequest(requestParams) withSignersFromBothCommittees {
        multisig.tryApprove(
            signerInFirstCommittee,
            currentRequest.hash,
            requestParams.id
        );
        multisig.tryApprove(
            signerInSecondCommittee,
            currentRequest.hash,
            requestParams.id
        );
    }

    modifier withApprovedRequest() {
        _craftApprovedRequest(testRequestParams);
        _;
    }

    modifier withExecutedRequest() {
        _craftApprovedRequest(testRequestParams);
        multisig.tryExecute(currentRequest.hash, currentRequest.params.id);
        _;
    }

    modifier withCommitteeSize(uint8 size, Committee committee) {
        // TODO: Mock committeeSize to eq. maxCommitteeSize
        for (uint8 i = 1; i <= size; i++) {
            multisig.addSigner(vm.addr(i), committee == Committee.First);
        }
        _;
    }

    constructor() {
        testRequestParams = RequestParams({ id: 0, message: 1337 });

        Multisig.Config memory config = Multisig.Config(
            firstCommitteeAcceptanceQuorum,
            secondCommitteeAcceptanceQuorum
        );

        multisig.configure(config);
    }

    function testMultisigInitState() public {
        assertEq(multisig.firstCommitteeAcceptanceQuorum, 1);
        assertEq(multisig.secondCommitteeAcceptanceQuorum, 1);
        assertEq(multisig.firstCommitteeSize, 0);
        assertEq(multisig.secondCommitteeSize, 0);
        assertEq(multisig.nextExecutionIndex, 0);
        _assertEq(
            multisig.signers[address(0)].status,
            Multisig.SignerStatus.Uninitialized
        );
        _assertEq(
            multisig.requests[bytes32(0)].status,
            Multisig.RequestStatus.NULL
        );
    }

    function testStatusWithNonExistentRequest() public {
        _assertEq(multisig.status(bytes32(0)), Multisig.RequestStatus.NULL);
    }

    function testStatusWithApprovedRequest() public withApprovedRequest {
        Multisig.Request memory request = multisig.requests[
            currentRequest.hash
        ];
        _assertEq(request.status, Multisig.RequestStatus.Accepted);
        _assertEq(multisig.status(currentRequest.hash), request.status);
    }

    function testStatusWithUndecidedRequest() public withUndecidedRequest {
        Multisig.Request memory request = multisig.requests[
            currentRequest.hash
        ];
        _assertEq(request.status, Multisig.RequestStatus.Undecided);
        _assertEq(multisig.status(currentRequest.hash), request.status);
    }

    function _testIsSigner(address possiblySigner) internal {
        assertTrue(multisig.isSigner(possiblySigner));
    }

    function testIsSignerForSignerFromFirstCommittee()
        public
        withSigner(Committee.First)
    {
        _testIsSigner(currentSigner);
    }

    function testIsSignerForSignerFromSecondCommittee()
        public
        withSigner(Committee.Second)
    {
        _testIsSigner(currentSigner);
    }

    function testIsSignerForNonExistentSigner() public {
        assertFalse(multisig.isSigner(currentSigner));
    }

    function testConstructorConfiguration() public {
        assertEq(
            multisig.firstCommitteeAcceptanceQuorum,
            firstCommitteeAcceptanceQuorum
        );
        assertEq(
            multisig.secondCommitteeAcceptanceQuorum,
            secondCommitteeAcceptanceQuorum
        );
    }

    function testConfigure() public {
        multisig.configure(Multisig.Config(2, 5));
        assertEq(multisig.firstCommitteeAcceptanceQuorum, 2);
        assertEq(multisig.secondCommitteeAcceptanceQuorum, 5);
    }

    function testConfigureRevertsOnInvalidFirstQuorum() public {
        vm.expectRevert(Multisig.InvalidConfiguration.selector);
        multisig.configure(Multisig.Config(0, secondCommitteeAcceptanceQuorum));

        vm.expectRevert(Multisig.InvalidConfiguration.selector);
        multisig.configure(
            Multisig.Config(
                Multisig.maxCommitteeSize + 1,
                secondCommitteeAcceptanceQuorum
            )
        );
    }

    function testConfigureRevertsOnInvalidSecondQuorum() public {
        vm.expectRevert(Multisig.InvalidConfiguration.selector);
        multisig.configure(Multisig.Config(firstCommitteeAcceptanceQuorum, 0));

        vm.expectRevert(Multisig.InvalidConfiguration.selector);
        multisig.configure(
            Multisig.Config(
                firstCommitteeAcceptanceQuorum,
                Multisig.maxCommitteeSize + 1
            )
        );
    }

    function _testAddSigner(Committee committee) internal {
        uint8 initialFirstCommitteeSize = multisig.firstCommitteeSize;
        uint8 initialSecondCommitteeSize = multisig.secondCommitteeSize;
        multisig.addSigner(signer, committee == Committee.First ? true : false);

        assertEq(
            multisig.firstCommitteeSize,
            committee == Committee.First
                ? initialFirstCommitteeSize + 1
                : initialFirstCommitteeSize
        );
        assertEq(
            multisig.secondCommitteeSize,
            committee == Committee.Second
                ? initialSecondCommitteeSize + 1
                : initialSecondCommitteeSize
        );

        Multisig.SignerInfo memory signerInfo = multisig.signers[signer];
        _assertEq(
            signerInfo.status,
            committee == Committee.First
                ? Multisig.SignerStatus.FirstCommittee
                : Multisig.SignerStatus.SecondCommittee
        );
        assertEq(
            signerInfo.index,
            multisig.firstCommitteeSize + multisig.secondCommitteeSize - 1
        );
    }

    function testAddSignerToFirstCommittee() public {
        _testAddSigner(Committee.First);
    }

    function testAddSignerToSecondCommittee() public {
        _testAddSigner(Committee.Second);
    }

    function testAddSignerRevertsIfMaxFirstCommitteeSizeReached()
        public
        withCommitteeSize(Multisig.maxCommitteeSize, Committee.First)
    {
        vm.expectRevert(Multisig.MaxCommitteeSizeReached.selector);
        multisig.addSigner(signer, true);
    }

    function testAddSignerRevertsIfMaxSecondCommitteeSizeReached()
        public
        withCommitteeSize(Multisig.maxCommitteeSize, Committee.Second)
    {
        vm.expectRevert(Multisig.MaxCommitteeSizeReached.selector);
        multisig.addSigner(signer, false);
    }

    function testAddSignerRevertsIfAlreadyExistsInSameCommittee() public {
        multisig.addSigner(signer, true);
        vm.expectRevert(
            abi.encodeWithSelector(
                Multisig.SignerAlreadyExists.selector,
                signer
            )
        );
        multisig.addSigner(signer, true);
    }

    function testAddSignerRevertsIfAlreadyExistsEvenInDifferentCommittee()
        public
    {
        multisig.addSigner(signer, true);
        vm.expectRevert(
            abi.encodeWithSelector(
                Multisig.SignerAlreadyExists.selector,
                signer
            )
        );
        multisig.addSigner(signer, false);
    }

    function testAddSignerRevertsIfAlreadyRemoved() public {
        multisig.addSigner(signer, true);
        multisig.removeSigner(signer);
        vm.expectRevert(
            abi.encodeWithSelector(
                Multisig.SignerAlreadyExists.selector,
                signer
            )
        );
        multisig.addSigner(signer, true);
    }

    function testFirstCommitteeCanHave128Members() public {
        for (uint8 i = 0; i < 128; i++) {
            multisig.addSigner(vm.addr(i + 1), true);
        }

        assertEq(multisig.firstCommitteeSize, 128);
    }

    function testSecondCommitteeCanHave128Members() public {
        for (uint8 i = 0; i < 128; i++) {
            multisig.addSigner(vm.addr(i + 1), false);
        }

        assertEq(multisig.secondCommitteeSize, 128);
    }

    function testBothCommitteesCanHave128Members() public {
        for (uint8 i = 0; i < 128; i++) {
            multisig.addSigner(vm.addr(i + 1), true);
            multisig.addSigner(vm.addr(128 + uint256(i) + 1), false);
        }

        assertEq(multisig.firstCommitteeSize, 128);
        assertEq(multisig.secondCommitteeSize, 128);
    }

    function _testRemoveSigner(
        Committee committee
    ) internal withSigner(committee) {
        multisig.removeSigner(currentSigner);
        Multisig.SignerInfo memory signerInfo = multisig.signers[currentSigner];
        _assertEq(signerInfo.status, Multisig.SignerStatus.Removed);
    }

    function testRemoveSignerFromFirstCommittee() public {
        _testRemoveSigner(Committee.First);
    }

    function testRemoveSignerFromSecondCommittee() public {
        _testRemoveSigner(Committee.Second);
    }

    function testRemoveSignerRevertsIfNotActive() public {
        vm.expectRevert(
            abi.encodeWithSelector(Multisig.SignerNotActive.selector, signer)
        );
        multisig.removeSigner(signer);
    }

    function _testRemoveSignerRevertsIfAlreadyRemoved(
        Committee committee
    ) internal {
        _testRemoveSigner(committee);
        vm.expectRevert(
            abi.encodeWithSelector(
                Multisig.SignerNotActive.selector,
                currentSigner
            )
        );
        multisig.removeSigner(currentSigner);
    }

    function testRemoveSignerFromFirstCommitteeRevertsIfAlreadyRemoved()
        public
    {
        _testRemoveSignerRevertsIfAlreadyRemoved(Committee.First);
    }

    function testRemoveSignerFromSecondCommitteeRevertsIfAlreadyRemoved()
        public
    {
        _testRemoveSignerRevertsIfAlreadyRemoved(Committee.Second);
    }

    function testTryApproveRevertsIfSignerNotActive() public withRequest {
        uint256 id = currentRequest.params.id;
        bytes32 hash = currentRequest.hash;

        vm.expectRevert(
            abi.encodeWithSelector(Multisig.SignerNotActive.selector, signer)
        );
        multisig.tryApprove(signer, hash, id);
    }

    function _testTryApproveIfSignerHasAlreadyApproved(
        Committee committee
    ) public withSigner(committee) withRequest {
        uint256 id = currentRequest.params.id;
        bytes32 hash = currentRequest.hash;

        Multisig.RequestStatusTransition firstTransition = multisig.tryApprove(
            currentSigner,
            hash,
            id
        );
        _assertEq(
            firstTransition,
            Multisig.RequestStatusTransition.NULLToUndecided
        );

        Multisig.RequestStatusTransition secondTransition = multisig.tryApprove(
            currentSigner,
            hash,
            id
        );
        _assertEq(secondTransition, Multisig.RequestStatusTransition.Unchanged);

        Multisig.SignerInfo memory signerInfo = multisig.signers[currentSigner];
        Multisig.Request memory request = multisig.requests[hash];
        uint256 signerMask = 1 << signerInfo.index;
        assertEq(request.approvers, signerMask);
        if (committee == Committee.First) {
            assertEq(request.approvalsFirstCommittee, 1);
            assertEq(request.approvalsSecondCommittee, 0);
        } else {
            assertEq(request.approvalsFirstCommittee, 0);
            assertEq(request.approvalsSecondCommittee, 1);
        }
        _assertEq(request.status, Multisig.RequestStatus.Undecided);
    }

    function testTryApproveIfSignerFromFirstCommitteeHasAlreadyApproved()
        public
    {
        _testTryApproveIfSignerHasAlreadyApproved(Committee.First);
    }

    function testTryApproveIfSignerFromSecondCommitteeHasAlreadyApproved()
        public
    {
        _testTryApproveIfSignerHasAlreadyApproved(Committee.Second);
    }

    function _testTryApproveCreatesNewRequest(
        Committee committee
    )
        internal
        withSigner(committee)
        withRequest
        returns (Multisig.Request memory)
    {
        uint256 id = currentRequest.params.id;
        bytes32 hash = currentRequest.hash;

        Multisig.RequestStatusTransition transition = multisig.tryApprove(
            currentSigner,
            hash,
            id
        );
        Multisig.SignerInfo memory signerInfo = multisig.signers[currentSigner];
        Multisig.Request memory request = multisig.requests[hash];
        uint256 signerMask = 1 << signerInfo.index;
        assertEq(request.approvers, signerMask);
        assertEq(multisig.approvedRequests[id], 0);
        _assertEq(request.status, Multisig.RequestStatus.Undecided);
        _assertEq(transition, Multisig.RequestStatusTransition.NULLToUndecided);

        return request;
    }

    function testTryApproveFromFirstCommitteeSigner() public {
        Multisig.Request memory request = _testTryApproveCreatesNewRequest(
            Committee.First
        );
        assertEq(request.approvalsFirstCommittee, 1);
        assertEq(request.approvalsSecondCommittee, 0);
    }

    function testTryApproveFromSecondCommitteeSigner() public {
        Multisig.Request memory request = _testTryApproveCreatesNewRequest(
            Committee.Second
        );
        assertEq(request.approvalsFirstCommittee, 0);
        assertEq(request.approvalsSecondCommittee, 1);
    }

    function _assertCorrectAcceptedRequestState(
        bytes32 hash,
        uint256 id
    ) internal {
        Multisig.Request memory request = multisig.requests[hash];
        Multisig.SignerInfo memory firstSignerInfo = multisig.signers[
            signerInFirstCommittee
        ];
        Multisig.SignerInfo memory secondSignerInfo = multisig.signers[
            signerInSecondCommittee
        ];
        uint256 firstSignerMask = 1 << firstSignerInfo.index;
        uint256 secondSignerMask = 1 << secondSignerInfo.index;
        assertEq(request.approvers, firstSignerMask | secondSignerMask);
        assertEq(multisig.approvedRequests[id], hash);
        // TODO
        _assertEq(request.status, Multisig.RequestStatus.Accepted);
    }

    function testTryApproveAcceptsRequest()
        public
        withSignersFromBothCommittees
        withRequest
    {
        uint256 id = currentRequest.params.id;
        bytes32 hash = currentRequest.hash;

        Multisig.RequestStatusTransition firstTransition = multisig.tryApprove(
            signerInFirstCommittee,
            hash,
            id
        );
        _assertEq(
            firstTransition,
            Multisig.RequestStatusTransition.NULLToUndecided
        );

        Multisig.RequestStatusTransition secondTransition = multisig.tryApprove(
            signerInSecondCommittee,
            hash,
            id
        );
        _assertEq(
            secondTransition,
            Multisig.RequestStatusTransition.UndecidedToAccepted
        );

        _assertCorrectAcceptedRequestState(hash, id);
    }

    function testTryApproveForAlreadyApprovedRequest()
        public
        withApprovedRequest
    {
        uint256 id = currentRequest.params.id;
        bytes32 hash = currentRequest.hash;

        Multisig.RequestStatusTransition transition = multisig.tryApprove(
            signerInSecondCommittee,
            hash,
            id
        );
        _assertEq(transition, Multisig.RequestStatusTransition.Unchanged);

        _assertCorrectAcceptedRequestState(hash, id);
    }

    function testTryApproveRevertsForReusedId() public withApprovedRequest {
        uint256 id = currentRequest.params.id;
        uint256 message2 = 31337;
        bytes32 hash2 = keccak256(abi.encodePacked(id, message2));
        vm.expectRevert(Multisig.InvalidId.selector);
        multisig.tryApprove(signerInFirstCommittee, hash2, id);
    }

    function testTryExecuteWithoutApprovedRequest() public withRequest {
        uint256 id = currentRequest.params.id;
        bytes32 hash = currentRequest.hash;
        assertEq(multisig.nextExecutionIndex, 0);
        bool success = multisig.tryExecute(hash, id);
        assertEq(multisig.nextExecutionIndex, 0);
        assertFalse(success);
    }

    function testTryExecuteWithNextApprovedRequest()
        public
        withApprovedRequest
    {
        uint256 id = currentRequest.params.id;
        bytes32 hash = currentRequest.hash;

        assertEq(multisig.nextExecutionIndex, 0);
        bool success = multisig.tryExecute(hash, id);
        assertEq(multisig.nextExecutionIndex, 1);
        assertTrue(success);
    }

    function testTryExecuteWithApprovedButNotNextApprovedRequest() public {
        _craftRequest(RequestParams({ id: 0, message: 1337 }));
        _craftApprovedRequest(currentRequest.params);

        _craftRequest(RequestParams({ id: 1, message: 31337 }));
        _craftApprovedRequest(currentRequest.params);

        uint256 id = currentRequest.params.id;
        bytes32 hash = currentRequest.hash;

        assertEq(multisig.nextExecutionIndex, 0);
        bool success = multisig.tryExecute(hash, id);
        assertEq(multisig.nextExecutionIndex, 0);
        assertFalse(success);
    }

    function testGetApproversForNonExistentRequest() public {
        bytes32 hash = keccak256(
            abi.encodePacked("this_request_does_not_exist")
        );
        (uint16[] memory approvers, uint16 count) = multisig.getApprovers(hash);
        assertEq(count, 0);
        _assertEq(approvers, new uint16[](0));
    }

    function testGetApproversForRequestWithoutApprovals() public withRequest {
        bytes32 hash = currentRequest.hash;
        (uint16[] memory approvers, uint16 count) = multisig.getApprovers(hash);
        assertEq(count, 0);
        _assertEq(approvers, new uint16[](0));
    }

    function testGetApproversForUndecidedRequest() public withUndecidedRequest {
        bytes32 hash = currentRequest.hash;
        uint16[] memory expectedApprovers = new uint16[](1);
        expectedApprovers[0] = 0;
        (uint16[] memory approvers, uint16 count) = multisig.getApprovers(hash);
        assertEq(count, 1);
        _assertEq(approvers, expectedApprovers);
    }

    function testGetApproversForUndecidedRequestWithMultipleApprovers()
        public
        withRequest
    {
        bytes32 hash = currentRequest.hash;
        uint256 id = currentRequest.params.id;
        multisig.configure(Multisig.Config(2, 3));

        multisig.addSigner(vm.addr(1), true);
        multisig.addSigner(vm.addr(2), true);
        multisig.addSigner(vm.addr(3), false);
        multisig.addSigner(vm.addr(4), false);
        multisig.addSigner(vm.addr(5), false);
        multisig.addSigner(vm.addr(6), false);

        multisig.tryApprove(vm.addr(1), hash, id);
        multisig.tryApprove(vm.addr(2), hash, id);
        multisig.tryApprove(vm.addr(4), hash, id);
        multisig.tryApprove(vm.addr(6), hash, id);

        uint16[] memory expectedApprovers = new uint16[](6);
        expectedApprovers[0] = 0;
        expectedApprovers[1] = 1;
        expectedApprovers[2] = 3;
        expectedApprovers[3] = 5;
        expectedApprovers[4] = 0;
        expectedApprovers[5] = 0;

        (uint16[] memory approvers, uint16 count) = multisig.getApprovers(hash);
        assertEq(count, 4);
        _assertEq(approvers, expectedApprovers);
    }

    function testGetApproversForApprovedRequest() public withApprovedRequest {
        bytes32 hash = currentRequest.hash;
        uint16[] memory expectedApprovers = new uint16[](2);
        expectedApprovers[0] = 0;
        expectedApprovers[1] = 1;
        (uint16[] memory approvers, uint16 count) = multisig.getApprovers(hash);
        assertEq(count, 2);
        _assertEq(approvers, expectedApprovers);
    }

    function testGetApproversForApprovedRequestWithMultipleSigners()
        public
        withRequest
    {
        bytes32 hash = currentRequest.hash;
        uint256 id = currentRequest.params.id;
        multisig.configure(Multisig.Config(3, 2));

        multisig.addSigner(vm.addr(1), true);
        multisig.addSigner(vm.addr(2), true);
        multisig.addSigner(vm.addr(3), true);
        multisig.addSigner(vm.addr(4), false);
        multisig.addSigner(vm.addr(5), false);

        multisig.tryApprove(vm.addr(1), hash, id);
        multisig.tryApprove(vm.addr(2), hash, id);
        multisig.tryApprove(vm.addr(3), hash, id);
        multisig.tryApprove(vm.addr(4), hash, id);
        multisig.tryApprove(vm.addr(5), hash, id);

        uint16[] memory expectedApprovers = new uint16[](5);
        expectedApprovers[0] = 0;
        expectedApprovers[1] = 1;
        expectedApprovers[2] = 2;
        expectedApprovers[3] = 3;
        expectedApprovers[4] = 4;

        (uint16[] memory approvers, uint16 count) = multisig.getApprovers(hash);
        assertEq(count, 5);
        _assertEq(approvers, expectedApprovers);
    }

    function testForceSetNextExecutionIndexRevertsOnSmallerIndex()
        public
        withExecutedRequest
    {
        vm.expectRevert(Multisig.InvalidNextExecutionIndex.selector);
        multisig.forceSetNextExecutionIndex(multisig.nextExecutionIndex - 1);
    }

    function testForceSetNextExecutionIndexRevertsOnUnchangedIndex() public {
        vm.expectRevert(Multisig.InvalidNextExecutionIndex.selector);
        multisig.forceSetNextExecutionIndex(multisig.nextExecutionIndex);
    }

    function testForceSetNextExecutionIndex() public {
        uint256 newNextExecutionIndex = multisig.nextExecutionIndex + 2;
        multisig.forceSetNextExecutionIndex(newNextExecutionIndex);
        assertEq(multisig.nextExecutionIndex, newNextExecutionIndex);
    }
}
