// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {WithAdmin} from "foundry-contracts/contracts/contracts-upgradeable/common/WithAdmin.sol";
import {IQuantumPortalPoc} from "../../../../quantumPortal/poc/IQuantumPortalPoc.sol";


/**
 * @notice Inherit this contract to acces basic QP behaviours
 */
abstract contract WithQp is Initializable, WithAdmin {
    /// @custom:storage-location erc7201:ferrum.storage.withqp.001
    struct WithQpStorageV001 {
        IQuantumPortalPoc portal;
    }
    
    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.withqp.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant WithQpStorageV001Location = 0xc8da6889c5c2b2b6193da08b65dc831c3bb6502971d7effb92705a0856a09900;

    function __WithQp_init(address initialOwnerAdmin, address _portal) internal onlyInitializing {
        __WithAdmin_init(initialOwnerAdmin, initialOwnerAdmin);
        __WithQp_init_unchained(_portal);
    }

    function __WithQp_init_unchained(address _portal) internal onlyInitializing {
        _initializeWithQp(_portal);
    }

    function _getWithQpStorageV001() internal pure returns (WithQpStorageV001 storage $) {
        assembly {
            $.slot := WithQpStorageV001Location
        }
    }

    function portal() public view returns (IQuantumPortalPoc) {
        return _getWithQpStorageV001().portal;
    }

    /**
     * @notice Upddates the qp portal
     * @param _portal the portal
     */
    function updatePortal(address _portal) external onlyOwner {
        WithQpStorageV001 storage $ = _getWithQpStorageV001();
        $.portal = IQuantumPortalPoc(_portal);
    }

    /**
     * @notice Initialize the multi-chain contract. Pass data using
     * the initiData
     */
    function initializeWithQp(address _portal) external onlyOwner virtual {
        _initializeWithQp(_portal);
    }

    function _initializeWithQp(address _portal) internal {
        WithQpStorageV001 storage $ = _getWithQpStorageV001();
        $.portal = IQuantumPortalPoc(_portal);
    }
}
