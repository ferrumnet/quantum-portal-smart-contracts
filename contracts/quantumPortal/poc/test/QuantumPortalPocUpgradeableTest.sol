// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../QuantumPortalPocUpgradeable.sol";

contract QuantumPortalPocUpgradeableTest is QuantumPortalPocUpgradeable {
    constructor(uint256 testChainId) PortalLedgerUpgradeable(testChainId) {}
}
