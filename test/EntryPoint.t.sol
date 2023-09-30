// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.15;

import "foundry-huff/HuffDeployer.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import {IEntryPoint} from "lib/I4337/src/IEntryPoint.sol";
import {UserOperation} from "lib/I4337/src/UserOperation.sol";

contract MinimalAccountTest is Test {

    IEntryPoint public entryPoint;

    function setUp() public {
        entryPoint = IEntryPoint(
            HuffDeployer.deploy("EntryPoint"));
    }

    function testValidateUserOp() public {
        UserOperation memory userOp = UserOperation({
            sender: address(0xbeefdead),
            nonce: 100,
            initCode: "INIT_CODE",
            callData: "CALL_DATA",
            callGasLimit: 300,
            verificationGasLimit: 8,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "PAYMASTER_DATA",
            signature: ""
        });
        UserOperation[] memory ops = new UserOperation[](2);
        ops[0] = userOp;
        ops[1] = userOp;
        console.log("ops");
        console.logBytes(abi.encodeWithSelector(
            entryPoint.handleOps.selector, ops, payable(address(0xdeadbeef))));
        entryPoint.handleOps(ops, payable(address(0xdeadbeef)));
    }
}
