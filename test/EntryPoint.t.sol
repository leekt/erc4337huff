// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.15;

import "foundry-huff/HuffDeployer.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import {IEntryPoint} from "lib/I4337/src/IEntryPoint.sol";
import {UserOperation} from "lib/I4337/src/UserOperation.sol";
import "solady/src/utils/ECDSA.sol";

interface AccountFactory {
    function createAccount(address owner, uint256 salt) external returns (address);
    function getAddress(address owner, uint256 salt) external view returns (address);
}

address constant MINIMAL_ACCOUNT_FACTORY_ADDRESS = 0xffD4505B3452Dc22f8473616d50503bA9E1710Ac;

bytes constant MINIMAL_ACCOUNT_FACTORY_BYTECODE =
    hex"5f3560e01c80635fbfb9cf1461001e5780638cb84e181461017b575f5ffd5b6004357f61010580600a3d393df336156100f25733735ff137d4b0fdcd49dca30c7cf57e5f527f578a026d27891415610101575f3560e01c633a871cdd1461004b575f5f6024366020527f038060245f375f60143560801c5f3560601c5af1005b7f19457468657265756d6040527f205369676e6564204d6573736167653a0a3332000000005f52602060206020606060527f24601c37603c5f205f525f602052604160216101a43560a5017f7fffffffffff6080527fffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a08135116100f860a0527f5703603f37602060805f60015afa50517300000000000000000000000000000060c05260601b60d1527f14156100f85760443580156100f2575f5f5f5f93335af15b60206080f35b600160e5527f5f5260205ff35b5f5ffd000000000000000000000000000000000000000000006101055260243561010f5f5ff55f5260205ff35b6004357f61010580600a3d393df336156100f25733735ff137d4b0fdcd49dca30c7cf57e5f527f578a026d27891415610101575f3560e01c633a871cdd1461004b575f5f6024366020527f038060245f375f60143560801c5f3560601c5af1005b7f19457468657265756d6040527f205369676e6564204d6573736167653a0a3332000000005f52602060206020606060527f24601c37603c5f205f525f602052604160216101a43560a5017f7fffffffffff6080527fffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a08135116100f860a0527f5703603f37602060805f60015afa50517300000000000000000000000000000060c05260601b60d1527f14156100f85760443580156100f2575f5f5f5f93335af15b60206080f35b600160e5527f5f5260205ff35b5f5ffd000000000000000000000000000000000000000000006101055261010f5f2060545260ff5f523060601b6020526024356034526055601f2060601b60601c60745260206074f3";

struct Owner {
    address addr;
    uint256 key;
}

contract MinimalAccountTest is Test {
    IEntryPoint public entryPoint;
    AccountFactory public factory;

    address entrypointAddress = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    Owner owner;

    function setUp() public {
        address huffEntryPoint = HuffDeployer.deploy("EntryPoint");
        entryPoint = IEntryPoint(entrypointAddress);
        vm.etch(entrypointAddress, huffEntryPoint.code);

        owner = Owner({key: uint256(1), addr: vm.addr(uint256(1))});

        factory = AccountFactory(MINIMAL_ACCOUNT_FACTORY_ADDRESS);
        vm.etch(address(factory), MINIMAL_ACCOUNT_FACTORY_BYTECODE);
    }

    function testValidateUserOp() public {
        UserOperation memory userOp = UserOperation({
            sender: factory.getAddress(address(this), 0),
            nonce: 100,
            initCode: abi.encodePacked(
                address(factory), abi.encodeWithSelector(factory.createAccount.selector, address(this), 0)
                ),
            callData: abi.encodePacked(address(this), uint128(0), ""),
            callGasLimit: 300,
            verificationGasLimit: 800,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "PAYMASTER_DATA",
            signature: ""
        });

        bytes32 opHash = entryPoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner.key, ECDSA.toEthSignedMessageHash(opHash));
        bytes memory signature = abi.encodePacked(v, r, s);
        userOp.signature = signature;

        UserOperation[] memory ops = new UserOperation[](2);
        ops[0] = userOp;
        ops[1] = userOp;
        // console.log("ops");
        // console.logBytes(abi.encodeWithSelector(entryPoint.handleOps.selector, ops, payable(address(0xdeadbeef))));
        entryPoint.handleOps(ops, payable(address(0xdeadbeef)));
    }
}
