// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 @notice This example contract, creates wrapped tokens.
 Holds a mapping between the original token and the wrapped token.
 When deposit is called from the portal, mints the "wrapped" amount to the "to" address
 When withdraw is called on the token, we call portals "withdraw" on the original chain.

 This example demonstrates how easily a two-way wrapped token bridge can be build using the 
 Ferrum Network Quantum Portal
 */
contract WrapperTokenBridge {

}

contract WrappedToken is ERC20 {
    constructor() ERC20("TEST", "TEST") {}
}