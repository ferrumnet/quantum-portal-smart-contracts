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
     * @param to Address to receive the withdrew funds
     * @param workRatioX128 Ratio of the total work by the worker
     * @param epoch Last work epoch
     */
    function withdrawFixedRemote(
        address to,
        uint256 workRatioX128,
        uint256 epoch
    ) external;

    /**
     * @notice Withdraw variable fees from the remote chain
     * @param to Address to receive the withdrew funds
     * @param workRatioX128 Ratio of the total work by the worker
     * @param epoch Last work epoch
     */
    function withdrawVariableRemote(
        address to,
        uint256 workRatioX128,
        uint256 epoch
    ) external;
}
