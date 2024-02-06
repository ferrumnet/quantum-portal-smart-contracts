// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWorkerInvestor {
    struct Relationship {
        address investor;
        uint8 deleted;
    }

    /**
     * @notice Returns the worker for an investor
     * @param workerAddress The worker
     * @return The investor `Relationship`
     */
    function getInvestor(
        address workerAddress
    ) external view returns (Relationship memory);
}
