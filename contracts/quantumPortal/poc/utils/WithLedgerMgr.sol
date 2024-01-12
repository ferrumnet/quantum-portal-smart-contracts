// SPDX-License-Identifier: MIT
import "foundry-contracts/contracts/common/WithAdmin.sol";

pragma solidity ^0.8.0;

/**
 * @notice Inherit this contract to acces basic QP behaviours
 */
abstract contract WithLedgerMgr is WithAdmin {
    address public qpLedgerMgr;

    modifier onlyMgr() {
        require(msg.sender == qpLedgerMgr, "QPWB:only QP mgr may call");
        _;
    }

    /**
     * @notice Ristricted: update the manager
     * @param mgr The manager contract address
     */
    function initializeWithLedgerMgr(address mgr) external virtual onlyOwner {
        _initializeWithLedgerMgr(mgr);
    }

    /**
     * @notice update the manager
     * @param mgr The manager contract address
     */
    function _initializeWithLedgerMgr(address mgr) internal {
        qpLedgerMgr = mgr;
    }
}

