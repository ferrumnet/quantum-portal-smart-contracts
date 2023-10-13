// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IQuantumPortalWorkPoolClient {
    /**
     * @notice Register work done by the entity (miner/validator)
     * @param remoteChain The remote chain ID
     * @param worker The worder
     * @param work Work amount
     * @param _remoteEpoch The remote block epoch
     */
    function registerWork(
        uint256 remoteChain,
        address worker,
        uint256 work,
        uint256 _remoteEpoch
    ) external;
}
