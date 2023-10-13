// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../QuantumPortalLedgerMgr.sol";

contract QuantumPortalLedgerMgrTest is QuantumPortalLedgerMgr {
    constructor(uint256 testChainId) QuantumPortalLedgerMgr(testChainId) {}
}
