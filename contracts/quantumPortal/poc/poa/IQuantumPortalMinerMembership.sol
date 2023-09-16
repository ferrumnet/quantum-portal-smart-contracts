// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IQuantumPortalMinerMembership {
    function selectMiner(
        address requestedMiner,
        bytes32 blockHash,
        uint256 blockTimestamp
    ) external returns (bool);

    function registerMiner(address miner) external;

    function unregisterMiner(address miner) external;

    function unregister() external;

    function findMiner(
        bytes32 blockHash,
        uint256 blockTimestamp
    ) external view returns (address);

    function findMinerAtTime(
        bytes32 blockHash,
        uint256 blockTimestamp,
        uint256 chainTimestamp
    ) external view returns (address);
}
