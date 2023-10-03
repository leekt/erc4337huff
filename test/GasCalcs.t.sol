// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.15;

import "foundry-huff/HuffDeployer.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import {UserOperation, UserOperationLib} from "account-abstraction/interfaces/UserOperation.sol";
import "solady/src/utils/ECDSA.sol";
import {IEntryPoint, EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {SimpleAccountFactory} from "account-abstraction/samples/SimpleAccountFactory.sol";

interface AccountFactory {
    function createAccount(address owner, uint256 salt) external returns (address);
    function getAddress(address owner, uint256 salt) external view returns (address);
}

address constant MINIMAL_ACCOUNT_FACTORY_ADDRESS = 0xffd4505b3452DC22f8473616d50503BA9e1710AD;

bytes constant MINIMAL_ACCOUNT_FACTORY_BYTECODE =
    hex"5f3560e01c80635fbfb9cf1461001e5780638cb84e181461017b575f5ffd5b6004357f61010580600a3d393df336156100f25733735ff137d4b0fdcd49dca30c7cf57e5f527f578a026d27891415610101575f3560e01c633a871cdd1461004b575f5f6024366020527f038060245f375f60143560801c5f3560601c5af1005b7f19457468657265756d6040527f205369676e6564204d6573736167653a0a3332000000005f52602060206020606060527f24601c37603c5f205f525f602052604160216101a43560a5017f7fffffffffff6080527fffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a08135116100f860a0527f5703603f37602060805f60015afa50517300000000000000000000000000000060c05260601b60d1527f14156100f85760443580156100f2575f5f5f5f93335af15b60206080f35b600160e5527f5f5260205ff35b5f5ffd000000000000000000000000000000000000000000006101055260243561010f5f5ff55f5260205ff35b6004357f61010580600a3d393df336156100f25733735ff137d4b0fdcd49dca30c7cf57e5f527f578a026d27891415610101575f3560e01c633a871cdd1461004b575f5f6024366020527f038060245f375f60143560801c5f3560601c5af1005b7f19457468657265756d6040527f205369676e6564204d6573736167653a0a3332000000005f52602060206020606060527f24601c37603c5f205f525f602052604160216101a43560a5017f7fffffffffff6080527fffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a08135116100f860a0527f5703603f37602060805f60015afa50517300000000000000000000000000000060c05260601b60d1527f14156100f85760443580156100f2575f5f5f5f93335af15b60206080f35b600160e5527f5f5260205ff35b5f5ffd000000000000000000000000000000000000000000006101055261010f5f2060545260ff5f523060601b6020526024356034526055601f2060601b60601c60745260206074f3";

struct Owner {
    address addr;
    uint256 key;
}

contract GasCalcs is Test {
    IEntryPoint public entryPoint;
    AccountFactory public factory;

    EntryPoint public solidityEntryPoint = new EntryPoint();
    SimpleAccountFactory public simpleAccountFactory = new SimpleAccountFactory(solidityEntryPoint);

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

    function testGasCalc1UO() public {
        // huff entrypoint
        address account1 = factory.getAddress(owner.addr, 0);
        vm.deal(account1, 1 ether);
        UserOperation memory userOp = UserOperation({
            sender: account1,
            nonce: 0,
            initCode: abi.encodePacked(
                address(factory), abi.encodeWithSelector(factory.createAccount.selector, owner.addr, 0)
                ),
            callData: abi.encodePacked(address(0x696969), uint128(1 wei), ""),
            callGasLimit: 3_000,
            verificationGasLimit: 800_000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "",
            signature: ""
        });
        userOp.signature = getUOSignature(userOp);

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOp;
        uint256 huffGas = gasleft();
        entryPoint.handleOps(ops, payable(address(0xdeadbeef)));
        huffGas = huffGas - gasleft();
        console.log("huff gas: %s", huffGas);

        // eth-infinitism entrypoint
        address simpleAccount1 = simpleAccountFactory.getAddress(owner.addr, 0);
        vm.deal(simpleAccount1, 1 ether);
        UserOperation memory simpleAccountUserOp = UserOperation({
            sender: simpleAccount1,
            nonce: 0,
            initCode: abi.encodePacked(
                address(simpleAccountFactory),
                abi.encodeWithSelector(simpleAccountFactory.createAccount.selector, owner.addr, 0)
                ),
            callData: abi.encodeWithSignature("execute(address,uint256,bytes)", address(0x696969), 1 wei, ""),
            callGasLimit: 3_000,
            verificationGasLimit: 800_000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "",
            signature: ""
        });
        simpleAccountUserOp.signature = getSolidityUOSignature(simpleAccountUserOp);

        UserOperation[] memory simpleAccountOps = new UserOperation[](1);
        simpleAccountOps[0] = simpleAccountUserOp;
        uint256 solidityGas = gasleft();
        solidityEntryPoint.handleOps(simpleAccountOps, payable(address(0xdeadbeef)));
        solidityGas = solidityGas - gasleft();
        console.log("solidity gas: %s", solidityGas);
    }

    function testGasCalc2UO() public {
        // huff entrypoint
        address account1 = factory.getAddress(owner.addr, 0);
        vm.deal(account1, 1 ether);
        UserOperation memory userOp = UserOperation({
            sender: account1,
            nonce: 0,
            initCode: abi.encodePacked(
                address(factory), abi.encodeWithSelector(factory.createAccount.selector, owner.addr, 0)
                ),
            callData: abi.encodePacked(address(0x696969), uint128(1 wei), ""),
            callGasLimit: 3_000,
            verificationGasLimit: 800_000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "",
            signature: ""
        });

        userOp.signature = getUOSignature(userOp);

        UserOperation memory userOp2 = UserOperation({
            sender: account1,
            nonce: 1,
            initCode: "",
            callData: abi.encodePacked(address(0x696969), uint128(1 wei), ""),
            callGasLimit: 3_000,
            verificationGasLimit: 800_000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "",
            signature: ""
        });

        userOp2.signature = getUOSignature(userOp2);

        UserOperation[] memory ops = new UserOperation[](2);
        ops[0] = userOp;
        ops[1] = userOp2;
        uint256 huffGas = gasleft();
        entryPoint.handleOps(ops, payable(address(0xdeadbeef)));
        huffGas = huffGas - gasleft();
        console.log("huff gas: %s", huffGas);

        // eth-infinitism entrypoint
        address simpleAccount1 = simpleAccountFactory.getAddress(owner.addr, 0);
        vm.deal(simpleAccount1, 1 ether);
        UserOperation memory simpleAccountUserOp = UserOperation({
            sender: simpleAccount1,
            nonce: 0,
            initCode: abi.encodePacked(
                address(simpleAccountFactory),
                abi.encodeWithSelector(simpleAccountFactory.createAccount.selector, owner.addr, 0)
                ),
            callData: abi.encodeWithSignature("execute(address,uint256,bytes)", address(0x696969), 1 wei, ""),
            callGasLimit: 3_000,
            verificationGasLimit: 800_000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "",
            signature: ""
        });
        simpleAccountUserOp.signature = getSolidityUOSignature(simpleAccountUserOp);

        UserOperation memory simpleAccountUserOp2 = UserOperation({
            sender: simpleAccount1,
            nonce: 1,
            initCode: "",
            callData: abi.encodeWithSignature("execute(address,uint256,bytes)", address(0x696969), 1 wei, ""),
            callGasLimit: 3_000,
            verificationGasLimit: 800_000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "",
            signature: ""
        });

        simpleAccountUserOp2.signature = getSolidityUOSignature(simpleAccountUserOp2);

        UserOperation[] memory simpleAccountOps = new UserOperation[](2);
        simpleAccountOps[0] = simpleAccountUserOp;
        simpleAccountOps[1] = simpleAccountUserOp2;
        uint256 solidityGas = gasleft();
        solidityEntryPoint.handleOps(simpleAccountOps, payable(address(0xdeadbeef)));
        solidityGas = solidityGas - gasleft();
        console.log("solidity gas: %s", solidityGas);
    }

    function testGasCalc10UO() public {
        // huff entrypoint
        address account1 = factory.getAddress(owner.addr, 0);
        vm.deal(account1, 1 ether);
        UserOperation memory userOp = UserOperation({
            sender: account1,
            nonce: 0,
            initCode: abi.encodePacked(
                address(factory), abi.encodeWithSelector(factory.createAccount.selector, owner.addr, 0)
                ),
            callData: abi.encodePacked(address(0x696969), uint128(1 wei), ""),
            callGasLimit: 3_000,
            verificationGasLimit: 800_000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "",
            signature: ""
        });

        userOp.signature = getUOSignature(userOp);

        UserOperation memory userOp2 = UserOperation({
            sender: account1,
            nonce: 1,
            initCode: "",
            callData: abi.encodePacked(address(0x696969), uint128(1 wei), ""),
            callGasLimit: 3_000,
            verificationGasLimit: 800_000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "",
            signature: ""
        });

        userOp2.signature = getUOSignature(userOp2);

        UserOperation memory userOp3 = UserOperation({
            sender: account1,
            nonce: 2,
            initCode: "",
            callData: abi.encodePacked(address(0x696969), uint128(1 wei), ""),
            callGasLimit: 3_000,
            verificationGasLimit: 800_000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "",
            signature: ""
        });

        userOp3.signature = getUOSignature(userOp3);

        UserOperation memory userOp4 = UserOperation({
            sender: account1,
            nonce: 3,
            initCode: "",
            callData: abi.encodePacked(address(0x696969), uint128(1 wei), ""),
            callGasLimit: 3_000,
            verificationGasLimit: 800_000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "",
            signature: ""
        });

        userOp4.signature = getUOSignature(userOp4);

        UserOperation memory userOp5 = UserOperation({
            sender: account1,
            nonce: 4,
            initCode: "",
            callData: abi.encodePacked(address(0x696969), uint128(1 wei), ""),
            callGasLimit: 3_000,
            verificationGasLimit: 800_000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "",
            signature: ""
        });

        userOp5.signature = getUOSignature(userOp5);

        UserOperation memory userOp6 = UserOperation({
            sender: account1,
            nonce: 5,
            initCode: "",
            callData: abi.encodePacked(address(0x696969), uint128(1 wei), ""),
            callGasLimit: 3_000,
            verificationGasLimit: 800_000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "",
            signature: ""
        });

        userOp6.signature = getUOSignature(userOp6);

        UserOperation memory userOp7 = UserOperation({
            sender: account1,
            nonce: 6,
            initCode: "",
            callData: abi.encodePacked(address(0x696969), uint128(1 wei), ""),
            callGasLimit: 3_000,
            verificationGasLimit: 800_000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "",
            signature: ""
        });

        userOp7.signature = getUOSignature(userOp7);

        UserOperation memory userOp8 = UserOperation({
            sender: account1,
            nonce: 7,
            initCode: "",
            callData: abi.encodePacked(address(0x696969), uint128(1 wei), ""),
            callGasLimit: 3_000,
            verificationGasLimit: 800_000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "",
            signature: ""
        });

        userOp8.signature = getUOSignature(userOp8);

        UserOperation memory userOp9 = UserOperation({
            sender: account1,
            nonce: 8,
            initCode: "",
            callData: abi.encodePacked(address(0x696969), uint128(1 wei), ""),
            callGasLimit: 3_000,
            verificationGasLimit: 800_000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "",
            signature: ""
        });

        userOp9.signature = getUOSignature(userOp9);

        UserOperation memory userOp10 = UserOperation({
            sender: account1,
            nonce: 9,
            initCode: "",
            callData: abi.encodePacked(address(0x696969), uint128(1 wei), ""),
            callGasLimit: 3_000,
            verificationGasLimit: 800_000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "",
            signature: ""
        });

        userOp10.signature = getUOSignature(userOp10);

        UserOperation[] memory ops = new UserOperation[](10);
        ops[0] = userOp;
        ops[1] = userOp2;
        ops[2] = userOp3;
        ops[3] = userOp4;
        ops[4] = userOp5;
        ops[5] = userOp6;
        ops[6] = userOp7;
        ops[7] = userOp8;
        ops[8] = userOp9;
        ops[9] = userOp10;
        uint256 huffGas = gasleft();
        entryPoint.handleOps(ops, payable(address(0xdeadbeef)));
        huffGas = huffGas - gasleft();
        console.log("huff gas: %s", huffGas);

        // eth-infinitism entrypoint
        address simpleAccount1 = simpleAccountFactory.getAddress(owner.addr, 0);
        vm.deal(simpleAccount1, 1 ether);
        UserOperation memory simpleAccountUserOp = UserOperation({
            sender: simpleAccount1,
            nonce: 0,
            initCode: abi.encodePacked(
                address(simpleAccountFactory),
                abi.encodeWithSelector(simpleAccountFactory.createAccount.selector, owner.addr, 0)
                ),
            callData: abi.encodeWithSignature("execute(address,uint256,bytes)", address(0x696969), 1 wei, ""),
            callGasLimit: 3_000,
            verificationGasLimit: 800_000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "",
            signature: ""
        });
        simpleAccountUserOp.signature = getSolidityUOSignature(simpleAccountUserOp);

        UserOperation memory simpleAccountUserOp2 = UserOperation({
            sender: simpleAccount1,
            nonce: 1,
            initCode: "",
            callData: abi.encodeWithSignature("execute(address,uint256,bytes)", address(0x696969), 1 wei, ""),
            callGasLimit: 3_000,
            verificationGasLimit: 800_000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "",
            signature: ""
        });

        simpleAccountUserOp2.signature = getSolidityUOSignature(simpleAccountUserOp2);

        UserOperation memory simpleAccountUserOp3 = UserOperation({
            sender: simpleAccount1,
            nonce: 2,
            initCode: "",
            callData: abi.encodeWithSignature("execute(address,uint256,bytes)", address(0x696969), 1 wei, ""),
            callGasLimit: 3_000,
            verificationGasLimit: 800_000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "",
            signature: ""
        });

        simpleAccountUserOp3.signature = getSolidityUOSignature(simpleAccountUserOp3);

        UserOperation memory simpleAccountUserOp4 = UserOperation({
            sender: simpleAccount1,
            nonce: 3,
            initCode: "",
            callData: abi.encodeWithSignature("execute(address,uint256,bytes)", address(0x696969), 1 wei, ""),
            callGasLimit: 3_000,
            verificationGasLimit: 800_000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "",
            signature: ""
        });

        simpleAccountUserOp4.signature = getSolidityUOSignature(simpleAccountUserOp4);

        UserOperation memory simpleAccountUserOp5 = UserOperation({
            sender: simpleAccount1,
            nonce: 4,
            initCode: "",
            callData: abi.encodeWithSignature("execute(address,uint256,bytes)", address(0x696969), 1 wei, ""),
            callGasLimit: 3_000,
            verificationGasLimit: 800_000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "",
            signature: ""
        });

        simpleAccountUserOp5.signature = getSolidityUOSignature(simpleAccountUserOp5);

        UserOperation memory simpleAccountUserOp6 = UserOperation({
            sender: simpleAccount1,
            nonce: 5,
            initCode: "",
            callData: abi.encodeWithSignature("execute(address,uint256,bytes)", address(0x696969), 1 wei, ""),
            callGasLimit: 3_000,
            verificationGasLimit: 800_000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "",
            signature: ""
        });

        simpleAccountUserOp6.signature = getSolidityUOSignature(simpleAccountUserOp6);

        UserOperation memory simpleAccountUserOp7 = UserOperation({
            sender: simpleAccount1,
            nonce: 6,
            initCode: "",
            callData: abi.encodeWithSignature("execute(address,uint256,bytes)", address(0x696969), 1 wei, ""),
            callGasLimit: 3_000,
            verificationGasLimit: 800_000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "",
            signature: ""
        });

        simpleAccountUserOp7.signature = getSolidityUOSignature(simpleAccountUserOp7);

        UserOperation memory simpleAccountUserOp8 = UserOperation({
            sender: simpleAccount1,
            nonce: 7,
            initCode: "",
            callData: abi.encodeWithSignature("execute(address,uint256,bytes)", address(0x696969), 1 wei, ""),
            callGasLimit: 3_000,
            verificationGasLimit: 800_000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "",
            signature: ""
        });

        simpleAccountUserOp8.signature = getSolidityUOSignature(simpleAccountUserOp8);

        UserOperation memory simpleAccountUserOp9 = UserOperation({
            sender: simpleAccount1,
            nonce: 8,
            initCode: "",
            callData: abi.encodeWithSignature("execute(address,uint256,bytes)", address(0x696969), 1 wei, ""),
            callGasLimit: 3_000,
            verificationGasLimit: 800_000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "",
            signature: ""
        });

        simpleAccountUserOp9.signature = getSolidityUOSignature(simpleAccountUserOp9);

        UserOperation memory simpleAccountUserOp10 = UserOperation({
            sender: simpleAccount1,
            nonce: 9,
            initCode: "",
            callData: abi.encodeWithSignature("execute(address,uint256,bytes)", address(0x696969), 1 wei, ""),
            callGasLimit: 3_000,
            verificationGasLimit: 800_000,
            preVerificationGas: 7,
            maxFeePerGas: 6,
            maxPriorityFeePerGas: 5,
            paymasterAndData: "",
            signature: ""
        });

        simpleAccountUserOp10.signature = getSolidityUOSignature(simpleAccountUserOp10);

        UserOperation[] memory simpleAccountOps = new UserOperation[](10);
        simpleAccountOps[0] = simpleAccountUserOp;
        simpleAccountOps[1] = simpleAccountUserOp2;
        simpleAccountOps[2] = simpleAccountUserOp3;
        simpleAccountOps[3] = simpleAccountUserOp4;
        simpleAccountOps[4] = simpleAccountUserOp5;
        simpleAccountOps[5] = simpleAccountUserOp6;
        simpleAccountOps[6] = simpleAccountUserOp7;
        simpleAccountOps[7] = simpleAccountUserOp8;
        simpleAccountOps[8] = simpleAccountUserOp9;
        simpleAccountOps[9] = simpleAccountUserOp10;
        uint256 solidityGas = gasleft();
        solidityEntryPoint.handleOps(simpleAccountOps, payable(address(0xdeadbeef)));
        solidityGas = solidityGas - gasleft();
        console.log("solidity gas: %s", solidityGas);
    }

    // Helper functions

    function getUOSignature(UserOperation memory userOp) public returns (bytes memory) {
        bytes32 opHash = entryPoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner.key, ECDSA.toEthSignedMessageHash(opHash));
        bytes memory signature = abi.encodePacked(v, r, s);
        return signature;
    }

    function getSolidityUOSignature(UserOperation memory userOp) public returns (bytes memory) {
        bytes32 opHash = solidityEntryPoint.getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner.key, ECDSA.toEthSignedMessageHash(opHash));
        bytes memory signature = abi.encodePacked(r, s, v);
        return signature;
    }
}
