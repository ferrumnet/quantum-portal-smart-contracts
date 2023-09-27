// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IQuantumPortalMinerMembership {

    /**
     * @notice Selects the miner
     * @param requestedMiner The requested miner
     * @param blockHash The block hash
     * @param blockTimestamp Timestamp of the block (from the remote chain)
     * @return If the miner selection was successful
     */
    function selectMiner(
        address requestedMiner,
        bytes32 blockHash,
        uint256 blockTimestamp
    ) external returns (bool);

    /**
     * @notice Register a miner
     * @param miner The miner address
     */
    function registerMiner(address miner) external;

    /**
     * @notice Unregister the miner. Can only be called by the mgr contract
     * @param miner The miner address
     */
    function unregisterMiner(address miner) external;

    /**
     * @notice Unregister self as miner
     */
    function unregister() external;

    /**
     * @notice Find a miner
     * @param blockHash The block hash
     * @param blockTimestamp The block timestamp on the source chain
     * @return The miner address
     */
    function findMiner(
        bytes32 blockHash,
        uint256 blockTimestamp
    ) external view returns (address);

    /**
     * @notice Find miner for a given block time (on the source chain)
     * @param blockHash The block hash
     * @param blockTimestamp The block timestamp on the source chain
     * @param chainTimestamp The target chain timestamp
     * @return The miner address
     */
    function findMinerAtTime(
        bytes32 blockHash,
        uint256 blockTimestamp,
        uint256 chainTimestamp
    ) external view returns (address);
}
