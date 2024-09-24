pragma solidity ^0.8.24;

import "../QpErc20Token.sol";

contract DummyUpgradedToken is QpErc20Token {
    function symbol() external override view returns (string memory) {
        return "DUMMY";
    }
}