pragma solidity ^0.8.0;

import {UserOperation, IAccount} from "I4337/IAccount.sol";
import {console} from "forge-std/console.sol";
contract TestWallet is IAccount {
    uint256 ret;

    function setRet(uint256 _ret) external {
        ret = _ret;
    }

    function deposit(address entryPoint) external payable {
        address(entryPoint).call{value: msg.value}("");
    }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns (uint256 validationData) {
        return ret;
    }
}
