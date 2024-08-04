// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../QuantumPortalPoc.sol";

contract QuantumPortalPocTest is QuantumPortalPoc {
    constructor(uint256 testChainId) PortalLedger(testChainId) {}
}
