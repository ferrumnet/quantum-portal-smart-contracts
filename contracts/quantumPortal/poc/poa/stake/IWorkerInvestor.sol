// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWorkerInvestor {
    struct Relationship {
        address investor;
        uint8 deleted;
    }

    /**
     * @notice Returns the worker for an investor
     * @param worker The worker
     * @return The investor `Relationship`
     */
    function getInvstor(
        address worker
    ) external view returns (Relationship memory);
}
