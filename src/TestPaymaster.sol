import "I4337/IPaymaster.sol";

contract TestPaymaster is IPaymaster {

    function deposit(address entryPoint) external payable {
        address(entryPoint).call{value: msg.value}("");
    }

    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external override returns (bytes memory context, uint256 validationData) {
        return ("", 0);
    }

    function postOp(
        PostOpMode,
        bytes calldata,
        uint256 actualGasCost
    ) external override {
    }
}
