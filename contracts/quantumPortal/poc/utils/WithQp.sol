// SPDX-License-Identifier: MIT
import "../IQuantumPortalPoc.sol";
import "foundry-contracts/contracts/common/WithAdmin.sol";

pragma solidity ^0.8.0;

/**
 * @notice Inherit this contract to acces basic QP behaviours
 */
abstract contract WithQp is WithAdmin {
    IQuantumPortalPoc public portal;

    /**
     * @notice Upddates the qp portal
     * @param _portal the portal
     */
    function updatePortal(address _portal) external onlyOwner {
        portal = IQuantumPortalPoc(_portal);
    }

    /**
     * @notice Initialize the multi-chain contract. Pass data using
     * the initiData
     */
    function initializeWithQp(address _portal) external onlyOwner virtual {
        _initializeWithQp(_portal);
    }

    function _initializeWithQp(address _portal) internal {
        portal = IQuantumPortalPoc(_portal);
    }
}
