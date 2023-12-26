// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IQuantumPortalMinerMembership.sol";

import "hardhat/console.sol";

/**
 * @notice Membership management for the miner. A single unique miner can be selected for on a given hash for a time block.
 *         Miners can register, unregister, and replace.
 *         A miner stake is checked at the time of registration. It is upto the ledgerMgr to ensure selected
 *         miner has enough stake.
 *         Miner selection uses a time block. Another miner can replace a miner, if for the last block, two time blocks have
 *         passed. In this case the miner is allowed to be selected, and it will drop out the replaced miner.
 *         The replaced miner has to register again.
 */
abstract contract QuantumPortalMinerMembership is
    IQuantumPortalMinerMembership
{
    uint256 public timeBlockSize = 3 minutes; // Three minutes for a miner to react
    address[] public miners;
    mapping(address => uint256) public minerIdxsPlusOne; // Informational. Plus one so that we can have idx zero too

    /**
     * @notice Find a miner
     * @param blockHash The block hash
     * @param blockTimestamp The block timestamp on the source chain
     * @return The miner address
     */
    function findMiner(
        bytes32 blockHash,
        uint256 blockTimestamp
    ) external view override returns (address) {
        return findMinerAtTime(blockHash, blockTimestamp, block.timestamp);
    }

    /**
     * @notice Select the miner.
     *    Overwride and make sure this can only be called by the mgr
     * @param requestedMiner The requested miner
     * @param blockHash The block hash
     * @param blockTimestamp The block timestamp
     */
    function _selectMiner(
        address requestedMiner,
        bytes32 blockHash,
        uint256 blockTimestamp
    ) internal returns (bool) {
        console.log("Selecting miner", requestedMiner);
        uint256 offset = (block.timestamp - blockTimestamp) %
            (timeBlockSize * 2);
        uint256 registeredMinerIdx = minerIdx(
            blockHash,
            blockTimestamp,
            offset
        );
        console.log(
            "Random miner IDX",
            registeredMinerIdx,
            miners[registeredMinerIdx]
        );
        address registeredMiner = miners[registeredMinerIdx];
        if (registeredMiner != requestedMiner) {
            return false;
        }
        if (offset != 0) {
            // Unregister the initial miner that was not active
            uint256 originalMinerIdx = minerIdx(blockHash, blockTimestamp, 0);
            if (originalMinerIdx != registeredMinerIdx) {
                // If there is more than one miner
                unregisterMinerByIdx(originalMinerIdx);
            }
        }
        return true;
    }

    /**
     * @notice Finds miner for a specific time (on the local chain)
     *  To be used by client to verify if they are the miner or not
     * @param blockHash The block hash
     * @param blockTimestamp The block timestamp
     * @param chainTimestamp The chain timestamp
     */
    function findMinerAtTime(
        bytes32 blockHash,
        uint256 blockTimestamp,
        uint256 chainTimestamp
    ) public view override returns (address) {
        uint256 offset = (chainTimestamp - blockTimestamp) %
            (timeBlockSize * 2);
        uint256 registeredMinerIdx = minerIdx(
            blockHash,
            blockTimestamp,
            offset
        );
        return miners[registeredMinerIdx];
    }

    /**
     * @notice Calcualte the miner index
     * @param blockHash The block hash
     * @param blockTimestamp The block timestamp
     * @param offset The time offset since the block was mined on the source chain
     */
    function minerIdx(
        bytes32 blockHash,
        uint256 blockTimestamp,
        uint256 offset
    ) internal view returns (uint256) {
        uint256 blockEpoch = blockTimestamp / timeBlockSize;
        uint256 idx = uint256(blockHash) << (64 + blockEpoch + offset);
        return idx % miners.length;
    }

    /**
     * @notice Unregister a miner
     * @param miner The miner
     */
    function _unregisterMiner(address miner) internal {
        uint256 idx = minerIdxsPlusOne[miner];
        require(idx != 0, "QPMM: miner not registered");
        unregisterMinerByIdx(idx - 1);
    }

    /**
     * @notice Unregister a miner by its index
     * @param idx The miner index
     */
    function unregisterMinerByIdx(uint256 idx) internal {
        uint256 last = miners.length - 1;
        address miner = miners[idx];
        delete minerIdxsPlusOne[miner];
        if (idx != last) {
            address lastMiner = miners[last];
            miners[idx] = lastMiner;
            minerIdxsPlusOne[lastMiner] = idx + 1;
        }
        miners.pop();
    }

    /**
     * @notice Ensure it is only called by the mgr. And there is enough stake before registering.
     *         Consider including a
     * @param miner The miner
     */
    function _registerMiner(address miner) internal {
        require(minerIdxsPlusOne[miner] == 0, "QPMM: already registered");
        miners.push(miner);
        minerIdxsPlusOne[miner] = miners.length;
    }
}
