pragma solidity ^0.8.0;

import {UserOperation, IAccount} from "I4337/IAccount.sol";
import {console} from "forge-std/console.sol";
contract TestWallet is IAccount {
    uint256 ret;

    function setRet(uint256 _ret) external {
        ret = _ret;
    }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns (uint256 validationData) {
        console.log("TestWallet: validateUserOp");
        console.logBytes(msg.data);
        return ret;
    }
}
