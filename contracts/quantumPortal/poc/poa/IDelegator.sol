// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDelegator {
    struct ReverseDelegation {
        address delegatee;
        uint8 deleted;
    }

    function getReverseDelegation(
        address key
    ) external view returns (ReverseDelegation memory);
}
