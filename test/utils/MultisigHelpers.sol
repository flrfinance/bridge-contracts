// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

abstract contract MultisigHelpers {
    uint8 constant firstCommitteeAcceptanceQuorum = 1;
    uint8 constant secondCommitteeAcceptanceQuorum = 1;

    address constant signer = 0xD65092e7bBe1f3D3269e8E8E9Ae3d98fF69E377b;
    address constant signerA = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address constant signerB = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

    enum Committee {
        First,
        Second
    }
}
