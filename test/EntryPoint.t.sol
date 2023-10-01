// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.15;

import "foundry-huff/HuffDeployer.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import {IEntryPoint} from "lib/I4337/src/IEntryPoint.sol";
import {UserOperation} from "lib/I4337/src/UserOperation.sol";
import {TestWallet} from "src/TestWallet.sol";

contract MinimalAccountTest is Test {

    IEntryPoint public entryPoint;
    TestWallet public wallet;

    function setUp() public {
        entryPoint = IEntryPoint(
            HuffDeployer.deploy("EntryPoint"));
        wallet = new TestWallet();
    }

    function testValidateUserOp() public {
        vm.warp(10000);
        UserOperation memory userOp = UserOperation({
            sender: address(wallet),
            nonce: 100,
            initCode: "INIT_CODE",
            callData: "CALL_DATA",
            callGasLimit: 60000,
            verificationGasLimit: 50000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "PAYMASTER_DATA",
            signature: ""
        });
        UserOperation[] memory ops = new UserOperation[](2);
        ops[0] = userOp;
        ops[1] = userOp;

        uint256 validAfter = block.timestamp - 10;
        uint256 validUntil = block.timestamp + 10;
        uint256 res = validAfter << 208 | validUntil << 160;
        wallet.setRet(res);
        console.log("ops");
        console.logBytes(abi.encodeWithSelector(
            entryPoint.handleOps.selector, ops, payable(address(0xdeadbeef))));
        entryPoint.handleOps(ops, payable(address(0xdeadbeef)));
    }
}
