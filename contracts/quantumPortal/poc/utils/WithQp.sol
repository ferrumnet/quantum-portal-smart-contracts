// SPDX-License-Identifier: MIT
import "../IQuantumPortalPoc.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity ^0.8.0;

/**
 * @notice Inherit this contract to acces basic QP behaviours
 */
abstract contract WithQp is Ownable {
    IQuantumPortalPoc public portal;

    /**
     * @notice Initialize the multi-chain contract. Pass data using
     * the initiData
     */
    function initialize(address _portal) external onlyOwner virtual {
        portal = IQuantumPortalPoc(_portal);
    }
}
