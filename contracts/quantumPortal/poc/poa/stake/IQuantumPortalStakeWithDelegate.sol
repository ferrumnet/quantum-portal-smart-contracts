// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IQuantumPortalStakeWithDelegate {
    /**
     * @notice Return stake for an investor given the worker
     * @param worker The actor id. Miner / validator
     */
    function stakeOfInvestor(
        address worker
    ) external view returns (uint256);

    /**
     * @notice Returns the assgined investor for staker 
     * @param staker The staker
     */
    function investorDelegations(
        address staker
    ) external view returns (address);

    /**
     * The stake ID
     */
    function STAKE_ID() external view returns (address);

    /**
     * @notice Delegates the stake to an investor if not set. 
     *   If staker has already delegated to someone else, will revert
     * @param investor The investor (miner/validator)
     * @param staker The staker
     */
    function setInvestorDelegations(
        address investor,
        address staker
    ) external;
}
