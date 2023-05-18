// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IQuantumPortalWorkPoolClient {
    function registerWork(uint256 remoteChain, address worker, uint256 work, uint256 _remoteEpoch) external;
}