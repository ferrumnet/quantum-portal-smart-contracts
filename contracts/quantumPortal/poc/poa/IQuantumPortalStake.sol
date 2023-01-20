// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IQuantumPortalStake {
    function delegatedStakeOf(address delegatee) external returns (uint256);
}