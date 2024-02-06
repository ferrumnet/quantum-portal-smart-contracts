// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IQuantumPortalStake {
    /**
     * @notice Return stake for a delegatee
     * @param actor The actor id. Miner / validator
     */
    function delegatedStakeOf(
        address actor
    ) external view returns (uint256);

    /**
     * The stake ID
     */
    function STAKE_ID() external view returns (address);
}
