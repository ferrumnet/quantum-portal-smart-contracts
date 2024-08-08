// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {WithAdminUpgradeable} from "foundry-contracts/contracts/contracts-upgradeable/common/WithAdminUpgradeable.sol";


/**
 * @notice Inherit this contract to acces basic QP behaviours
 */
abstract contract WithLedgerMgrUpgradeable is Initializable, WithAdminUpgradeable {
    /// @custom:storage-location erc7201:ferrum.storage.withledgermgr.001
    struct WithLedgerMgrStorageV001 {
        address qpLedgerMgr;
    }

    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.withledgermgr.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant WithLedgerMgrStorageV001Location = 0x5593c8ce522d852156b23716c175161197524393224949a6b94777d84f696e00;

    modifier onlyMgr() {
        require(msg.sender == _getWithLedgerMgrStorageV001().qpLedgerMgr, "QPWB:only QP mgr may call");
        _;
    }

    function _getWithLedgerMgrStorageV001() internal pure returns (WithLedgerMgrStorageV001 storage $) {
        assembly {
            $.slot := WithLedgerMgrStorageV001Location
        }
    }

    function __WithLedgerMgr_init(address initialOwnerAdmin, address mgr) internal onlyInitializing {
        __WithAdmin_init(initialOwnerAdmin, initialOwnerAdmin);
        __WithLedgerMgr_init_unchained(mgr);
    }

    function __WithLedgerMgr_init_unchained(address mgr) internal onlyInitializing {
        _initializeWithLedgerMgr(mgr);
    }

    function qpLedgerMgr() public view returns (address) {
        return _getWithLedgerMgrStorageV001().qpLedgerMgr;
    }

    /**
     * @notice Updates the ledger mgr
     * @param mgr The ledger mgr
     */
    function updateLedgerMgr(address mgr) external onlyOwner {
        WithLedgerMgrStorageV001 storage $ = _getWithLedgerMgrStorageV001();
        $.qpLedgerMgr = mgr;
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
        WithLedgerMgrStorageV001 storage $ = _getWithLedgerMgrStorageV001();
        $.qpLedgerMgr = mgr;
    }
}
