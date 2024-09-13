// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../QuantumPortalLedgerMgrUpgradeable.sol";

contract QuantumPortalLedgerMgrUpgradeableTest is QuantumPortalLedgerMgrUpgradeable {
    constructor(uint256 testChainId) QuantumPortalLedgerMgrUpgradeable(testChainId) {}

    function realChainId() public view returns (uint256) {
        return block.chainid;
    }
}
