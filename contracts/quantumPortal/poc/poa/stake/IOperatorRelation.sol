// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOperatorRelation {
    struct Relationship {
        address delegate;
        uint8 deleted;
    }

    /**
     * @notice Returns the delegate for a node operator
     * @param nodeOperator The worker
     * @return The investor `Relationship`
     */
    function getDelegateForOperator(
        address nodeOperator
    ) external view returns (Relationship memory);
}
