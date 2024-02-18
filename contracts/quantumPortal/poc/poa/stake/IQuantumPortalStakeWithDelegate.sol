// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IQuantumPortalStakeWithDelegate {
    /**
     * @notice Return stake for an investor given the worker
     * @param operator The actor id. Miner / validator
     */
    function stakeOfDelegate(
        address operator
    ) external view returns (uint256);

    /**
     * @notice Returns the assgined delegate for staker 
     * @param staker The staker
     */
    function delegations(
        address staker
    ) external view returns (address);

    /**
     * The stake ID
     */
    function STAKE_ID() external view returns (address);

    /**
     * @notice Delegates the stake to an investor if not set. 
     *   If staker has already delegated to someone else, will revert
     * @param delegate The delegate (miner/validator)
     * @param delegator The staker
     */
    function setDelegation(
        address delegate,
        address delegator
    ) external;

    /**
     * @notice Stakes with allocation. ONLY if stakeVerifyer is set
     * @param to The staker
     * @param delegate Delegate address
     * @param allocation Amount allowed
     * @param salt The salt
     * @param expiry Signature expiry
     * @param multiSignature The signature
     */
    function stakeToDelegateWithAllocation(
        address to,
        address delegate,
        uint256 allocation,
        bytes32 salt,
        uint64 expiry,
        bytes memory multiSignature
    ) external;
}
