// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./IQuantumPortalLedgerMgr.sol";
import "./QuantumPortalLib.sol";
import "foundry-contracts/contracts/common/WithAdmin.sol";

contract QuantumPortalState is WithAdmin {
    string public constant VERSION = "0.0.1";
    mapping(uint256 => IQuantumPortalLedgerMgr.LocalBlock) private localBlocks;
    mapping(uint256 => QuantumPortalLib.RemoteTransaction[])
        private localBlockTransactions;
    mapping(uint256 => IQuantumPortalLedgerMgr.MinedBlock) private minedBlocks;
    mapping(uint256 => QuantumPortalLib.RemoteTransaction[])
        private minedBlockTransactions;
    mapping(uint256 => QuantumPortalLib.Block) private lastLocalBlock; // One block nonce per remote chain. txs local, to be run remotely
    mapping(uint256 => QuantumPortalLib.Block) private lastMinedBlock; // One block nonce per remote chain. txs remote, to be run on here
    mapping(uint256 => QuantumPortalLib.Block) private lastFinalizedBlock;
    mapping(uint256 => IQuantumPortalLedgerMgr.FinalizationMetadata)
        private finalizations;
    mapping(uint256 => IQuantumPortalLedgerMgr.FinalizerStake[])
        private finalizationStakes;

    mapping(uint256 => mapping(address => mapping(address => uint256))) remoteBalances;

    address public mgr;
    address public ledger;

    /**
     * @notice Only allow the QP ledger manager to call
     */
    modifier onlyMgr() {
        require(msg.sender == mgr, "QPS: Not allowed");
        _;
    }

    /**
     * @notice Only allow QP ledger to call
     */
    modifier onlyLedger() {
        require(msg.sender == ledger, "QPS: Not allowed");
        _;
    }

    /**
     * @notice Get the local block
     * @param key The key
     */
    function getLocalBlocks(
        uint256 key
    ) external view returns (IQuantumPortalLedgerMgr.LocalBlock memory) {
        return localBlocks[key];
    }

    /**
     * @notice Sets the local block
     * @param key The key
     * @param value The block
     */
    function setLocalBlocks(
        uint256 key,
        IQuantumPortalLedgerMgr.LocalBlock calldata value
    ) external onlyMgr {
        localBlocks[key] = value;
    }

    /**
     * @notice Push local block transactions
     * @param key The key
     * @param value The remote transaction
     */
    function pushLocalBlockTransactions(
        uint256 key,
        QuantumPortalLib.RemoteTransaction memory value
    ) external onlyMgr {
        localBlockTransactions[key].push(value);
    }

    /**
     * @notice Get the local block transaction length
     * @param key The key
     */
    function getLocalBlockTransactionLength(
        uint256 key
    ) external view returns (uint256) {
        return localBlockTransactions[key].length;
    }

    /**
     * @notice Get the local block transaction
     * @param key They key
     * @param idx The tx index
     */
    function getLocalBlockTransaction(
        uint256 key,
        uint256 idx
    ) external view returns (QuantumPortalLib.RemoteTransaction memory) {
        return localBlockTransactions[key][idx];
    }

    /**
     * @notice Get all local block transactions
     * @param key The key
     */
    function getLocalBlockTransactions(
        uint256 key
    )
        external
        view
        returns (QuantumPortalLib.RemoteTransaction[] memory value)
    {
        value = localBlockTransactions[key];
    }

    /**
     * @notice Get the mined block
     * @param key The key
     */
    function getMinedBlock(
        uint256 key
    ) external view returns (IQuantumPortalLedgerMgr.MinedBlock memory) {
        return minedBlocks[key];
    }

    /**
     * @notice Set the mined block
     * @param key The key
     * @param value The block
     */
    function setMinedBlock(
        uint256 key,
        IQuantumPortalLedgerMgr.MinedBlock calldata value
    ) external onlyMgr {
        minedBlocks[key] = value;
    }

    /**
     * @notice Set the mined block as invalid
     * @param key The block key
     */
    function setMinedBlockAsInvalid(uint256 key) external onlyMgr {
        minedBlocks[key].invalidBlock = 1;
    }

    /**
     * @notice Get the mined block transactinos
     * @param key The block key
     */
    function getMinedBlockTransactions(
        uint256 key
    )
        external
        view
        returns (QuantumPortalLib.RemoteTransaction[] memory value)
    {
        value = minedBlockTransactions[key];
    }

    /**
     * @notice Push the mined block transactions
     * @param key The block key
     * @param value The retmoe transaction
     */
    function pushMinedBlockTransactions(
        uint256 key,
        QuantumPortalLib.RemoteTransaction memory value
    ) external onlyMgr {
        minedBlockTransactions[key].push(value);
    }

    /**
     * @notice Get the last local block
     * @param key The block key
     */
    function getLastLocalBlock(
        uint256 key
    ) external view returns (QuantumPortalLib.Block memory) {
        return lastLocalBlock[key];
    }

    /**
     * @notice Set the last local block
     * @param key The block key
     * @param value The block
     */
    function setLastLocalBlock(
        uint256 key,
        QuantumPortalLib.Block calldata value
    ) external onlyMgr {
        lastLocalBlock[key] = value;
    }

    /**
     * @notice Get the last mined block
     * @param key The block key
     */
    function getLastMinedBlock(
        uint256 key
    ) external view returns (QuantumPortalLib.Block memory) {
        return lastMinedBlock[key];
    }

    /**
     * @notice Sets the last mined block
     * @param key The key
     * @param value The block
     */
    function setLastMinedBlock(
        uint256 key,
        QuantumPortalLib.Block calldata value
    ) external onlyMgr {
        lastMinedBlock[key] = value;
    }

    /**
     * @notice Get the last finalized block
     * @param key The block key
     */
    function getLastFinalizedBlock(
        uint256 key
    ) external view returns (QuantumPortalLib.Block memory) {
        return lastFinalizedBlock[key];
    }

    /**
     * @notice Sets the last finalized block
     * @param key The block key
     * @param value The block
     */
    function setLastFinalizedBlock(
        uint256 key,
        QuantumPortalLib.Block calldata value
    ) external onlyMgr {
        lastFinalizedBlock[key] = value;
    }

    /**
     * @notice Set the finalization
     * @param key the block key
     * @param value The finalization metadata
     */
    function setFinalization(
        uint256 key,
        IQuantumPortalLedgerMgr.FinalizationMetadata memory value
    ) external onlyMgr {
        finalizations[key] = value;
    }

    /**
     * @notice Push the finalization stake
     * @param key The key
     * @param value The stake
     */
    function pushFinalizationStake(
        uint256 key,
        IQuantumPortalLedgerMgr.FinalizerStake memory value
    ) external onlyMgr {
        finalizationStakes[key].push(value);
    }

    /**
     * @notice Get the remote balances
     * @param chainId The chain ID
     * @param token The token
     * @param remoteContract The remote contract
     */
    function getRemoteBalances(
        uint256 chainId,
        address token,
        address remoteContract
    ) external view returns (uint256) {
        return remoteBalances[chainId][token][remoteContract];
    }

    /**
     * @notice Set the remote balances
     * @param chainId the chain ID
     * @param token The token
     * @param remoteContract The remote contract
     * @param value The balances
     */
    function setRemoteBalances(
        uint256 chainId,
        address token,
        address remoteContract,
        uint256 value
    ) external onlyLedger {
        remoteBalances[chainId][token][remoteContract] = value;
    }

    /**
     * @notice Set the ledger manager
     * @param _mgr The ledger manager
     */
    function setMgr(address _mgr) external onlyAdmin {
        mgr = _mgr;
    }

    /**
     * @notice Sets the ledger
     * @param _ledger The ledger
     */
    function setLedger(address _ledger) external onlyAdmin {
        ledger = _ledger;
    }
}
