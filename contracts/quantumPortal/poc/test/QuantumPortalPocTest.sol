// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../QuantumPortalPoc.sol";

contract QuantumPortalPocTest is QuantumPortalPoc {
    constructor(uint256 testChainId) PortalLedger(testChainId) Ownable(msg.sender) {}
}
