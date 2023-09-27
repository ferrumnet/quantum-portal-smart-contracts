// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IQuantumPortalWorkPoolServer {
    /**
     * @notice Collect fixed and variable fees
     * @param targetChainId The target chain ID
     * @param localEpoch Local block epoch
     * @param fixedFee Fixed fee part of the fee
     * @return varFee Variable fee amount collected
     */
    function collectFee(
        uint256 targetChainId,
        uint256 localEpoch,
        uint256 fixedFee
    ) external returns (uint256 varFee);

    /**
     * @notice Withdraw fixed fees from the remote chain
     * @param worker The worker who needs to be paid
     * @param workRatioX128 Ratio of the total work by the worker
     * @param epoch Last work epoch
     */
    function withdrawFixedRemote(
        address worker,
        uint256 workRatioX128,
        uint256 epoch
    ) external;

    /**
     * @notice Withdraw variable fees from the remote chain
     * @param worker The worker who needs to be paid
     * @param workRatioX128 Ratio of the total work by the worker
     * @param epoch Last work epoch
     */
    function withdrawVariableRemote(
        address worker,
        uint256 workRatioX128,
        uint256 epoch
    ) external;
}
