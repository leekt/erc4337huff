import "src/TestWallet.sol";

contract TestWalletFactory {
    function createWallet(bytes32 _salt) public returns (address) {
        return address(new TestWallet{salt: _salt}());
    }

    function getAddress(bytes32 _salt) public view returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            _salt,
            keccak256(abi.encodePacked(type(TestWallet).creationCode))
        )))));
    }
}
