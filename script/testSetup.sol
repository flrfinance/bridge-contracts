// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "../src/WrapDepositRedeem.sol";
import "../src/WrapMintBurn.sol";
import "../src/interfaces/IWrap.sol";
import "../src/libraries/Multisig.sol";

contract TestSetup is Script {
    uint8 constant firstCommitteeAcceptanceQuorum = 1;
    uint8 constant secondCommitteeAcceptanceQuorum = 1;
    uint8 constant protocolFeeBPS = 0;
    uint8 constant validatorFeeBPS = 0;
    address constant userAndOwner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address constant validator1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address constant validator2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    uint256 constant pkv =
        uint256(
            0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
        );

    function run() external {
        Multisig.Config memory c = Multisig.Config(
            firstCommitteeAcceptanceQuorum,
            secondCommitteeAcceptanceQuorum
        );
        IWrap.TokenInfo memory ti = IWrap.TokenInfo(1e21, 1e18, 0);

        vm.startBroadcast(userAndOwner);
        WrapDepositRedeem wrapDepositRedeem = new WrapDepositRedeem(
            c,
            validatorFeeBPS
        );
        WrapMintBurn wrapMintBurn = new WrapMintBurn(
            c,
            protocolFeeBPS,
            validatorFeeBPS
        );
        ERC20PresetMinterPauser token = new ERC20PresetMinterPauser(
            "Test",
            "TEST"
        );

        wrapDepositRedeem.addValidator(validator1, true, address(0));
        wrapDepositRedeem.addValidator(validator2, false, address(0));
        wrapMintBurn.addValidator(validator1, true, address(0));
        wrapMintBurn.addValidator(validator2, false, address(0));

        address wrapToken = wrapMintBurn.createAddToken(
            "TestWrap",
            "WTEST",
            address(0),
            address(token),
            18,
            ti
        );
        wrapDepositRedeem.addToken(address(token), wrapToken, ti);

        token.mint(userAndOwner, 1e20);

        token.approve(address(wrapDepositRedeem), 1e18);
        uint256 id = wrapDepositRedeem.deposit(
            address(token),
            1e18,
            userAndOwner
        );
        vm.stopBroadcast();

        // IWrap.RequestInfo memory r = IWrap.RequestInfo(id, address(token), 1e18, address(userAndOwner));
        // IWrap.RequestInfo[] memory rs = new IWrap.RequestInfo[](1);
        // rs[0] = r;

        // vm.startBroadcast(validator2);
        // wrapMintBurn.batchApproveExecute(rs);
        // vm.stopBroadcast();

        // vm.startBroadcast(validator1);
        // wrapMintBurn.batchApproveExecute(rs);
        // vm.stopBroadcast();
    }
}
