// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDelegator {
    struct ReverseDelegation {
        address delegatee;
        uint8 deleted;
    }

    /**
     * @notice Returns the reverse delegation for a delegatee
     * @param key The key
     * @return The reverse delegation as `ReverseDelegation`
     */
    function getReverseDelegation(
        address key
    ) external view returns (ReverseDelegation memory);
}
