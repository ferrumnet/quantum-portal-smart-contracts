// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICanEstimateGas {
    /**
     * @notice Estimates gas used by a transaction by running the tx, and reverting
     *    afterwards. This will not change any state
     * @param addr The contract address
     * @param method ABI encoded method call with parameters
     */
    function executeTxAndRevertToEstimateGas(
        address addr,
        bytes memory method
    ) external;
}
