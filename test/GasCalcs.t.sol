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

        bytes32 opHash = entryPoint.getUserOpHash(userOp);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(owner.key, ECDSA.toEthSignedMessageHash(opHash));
        bytes memory signature = abi.encodePacked(v2, r2, s2);
        userOp.signature = signature;

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

        bytes32 simpleAccountOpHash = solidityEntryPoint.getUserOpHash(simpleAccountUserOp);
        (uint8 simpleAccountv2, bytes32 simpleAccountr2, bytes32 simpleAccounts2) =
            vm.sign(owner.key, ECDSA.toEthSignedMessageHash(simpleAccountOpHash));
        bytes memory simpleAccountSignature = abi.encodePacked(simpleAccountr2, simpleAccounts2, simpleAccountv2);
        simpleAccountUserOp.signature = simpleAccountSignature;

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

        bytes32 opHash = entryPoint.getUserOpHash(userOp);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(owner.key, ECDSA.toEthSignedMessageHash(opHash));
        bytes memory signature = abi.encodePacked(v2, r2, s2);
        userOp.signature = signature;

        bytes32 opHash2 = entryPoint.getUserOpHash(userOp2);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(owner.key, ECDSA.toEthSignedMessageHash(opHash2));
        bytes memory signature2 = abi.encodePacked(v, r, s);
        userOp2.signature = signature2;

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOp;
        // ops[1] = userOp2;
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

        bytes32 simpleAccountOpHash = solidityEntryPoint.getUserOpHash(simpleAccountUserOp);
        (uint8 simpleAccountv2, bytes32 simpleAccountr2, bytes32 simpleAccounts2) =
            vm.sign(owner.key, ECDSA.toEthSignedMessageHash(simpleAccountOpHash));
        bytes memory simpleAccountSignature = abi.encodePacked(simpleAccountr2, simpleAccounts2, simpleAccountv2);
        simpleAccountUserOp.signature = simpleAccountSignature;

        bytes32 simpleAccountOpHash2 = solidityEntryPoint.getUserOpHash(simpleAccountUserOp2);
        (uint8 simpleAccountv, bytes32 simpleAccountr, bytes32 simpleAccounts) =
            vm.sign(owner.key, ECDSA.toEthSignedMessageHash(simpleAccountOpHash2));
        bytes memory simpleAccountSignature2 = abi.encodePacked(simpleAccountr, simpleAccounts, simpleAccountv);
        simpleAccountUserOp2.signature = simpleAccountSignature2;

        UserOperation[] memory simpleAccountOps = new UserOperation[](1);
        simpleAccountOps[0] = simpleAccountUserOp;
        // simpleAccountOps[1] = simpleAccountUserOp2;
        uint256 solidityGas = gasleft();
        solidityEntryPoint.handleOps(simpleAccountOps, payable(address(0xdeadbeef)));
        solidityGas = solidityGas - gasleft();
        console.log("solidity gas: %s", solidityGas);
    }

    // Helper functions

    function pack(UserOperation memory userOp) internal pure returns (bytes memory ret) {
        address sender = userOp.sender;
        uint256 nonce = userOp.nonce;
        bytes32 hashInitCode = keccak256(userOp.initCode);
        bytes32 hashCallData = keccak256(userOp.callData);
        uint256 callGasLimit = userOp.callGasLimit;
        uint256 verificationGasLimit = userOp.verificationGasLimit;
        uint256 preVerificationGas = userOp.preVerificationGas;
        uint256 maxFeePerGas = userOp.maxFeePerGas;
        uint256 maxPriorityFeePerGas = userOp.maxPriorityFeePerGas;
        bytes32 hashPaymasterAndData = keccak256(userOp.paymasterAndData);

        return abi.encode(
            sender,
            nonce,
            hashInitCode,
            hashCallData,
            callGasLimit,
            verificationGasLimit,
            preVerificationGas,
            maxFeePerGas,
            maxPriorityFeePerGas,
            hashPaymasterAndData
        );
    }

    function calldataKeccak(bytes memory data) internal pure returns (bytes32 ret) {
        assembly {
            ret := keccak256(mload(0x00), mload(0x20))
        }
    }
}
