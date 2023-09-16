// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./IQuantumPortalLedgerMgr.sol";
import "./QuantumPortalLib.sol";
import "foundry-contracts/contracts/common/WithAdmin.sol";

contract QuantumPortalState is WithAdmin {
    modifier onlyMgr() {
        require(msg.sender == mgr, "QPS: Not allowed");
        _;
    }

    modifier onlyLedger() {
        require(msg.sender == ledger, "QPS: Not allowed");
        _;
    }

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

    function getLocalBlocks(
        uint256 key
    ) external view returns (IQuantumPortalLedgerMgr.LocalBlock memory) {
        return localBlocks[key];
    }

    function setLocalBlocks(
        uint256 key,
        IQuantumPortalLedgerMgr.LocalBlock calldata value
    ) external onlyMgr {
        localBlocks[key] = value;
    }

    function pushLocalBlockTransactions(
        uint256 key,
        QuantumPortalLib.RemoteTransaction memory value
    ) external onlyMgr {
        localBlockTransactions[key].push(value);
    }

    function getLocalBlockTransactionLength(
        uint256 key
    ) external view returns (uint256) {
        return localBlockTransactions[key].length;
    }

    function getLocalBlockTransaction(
        uint256 key,
        uint256 idx
    ) external view returns (QuantumPortalLib.RemoteTransaction memory) {
        return localBlockTransactions[key][idx];
    }

    function getLocalBlockTransactions(
        uint256 key
    )
        external
        view
        returns (QuantumPortalLib.RemoteTransaction[] memory value)
    {
        value = localBlockTransactions[key];
    }

    function getMinedBlock(
        uint256 key
    ) external view returns (IQuantumPortalLedgerMgr.MinedBlock memory) {
        return minedBlocks[key];
    }

    function setMinedBlock(
        uint256 key,
        IQuantumPortalLedgerMgr.MinedBlock calldata value
    ) external onlyMgr {
        minedBlocks[key] = value;
    }

    function setMinedBlockAsInvalid(uint256 key) external onlyMgr {
        minedBlocks[key].invalidBlock = 1;
    }

    function getMinedBlockTransactions(
        uint256 key
    )
        external
        view
        returns (QuantumPortalLib.RemoteTransaction[] memory value)
    {
        value = minedBlockTransactions[key];
    }

    function pushMinedBlockTransactions(
        uint256 key,
        QuantumPortalLib.RemoteTransaction memory value
    ) external onlyMgr {
        minedBlockTransactions[key].push(value);
    }

    function getLastLocalBlock(
        uint256 key
    ) external view returns (QuantumPortalLib.Block memory) {
        return lastLocalBlock[key];
    }

    function setLastLocalBlock(
        uint256 key,
        QuantumPortalLib.Block calldata value
    ) external onlyMgr {
        lastLocalBlock[key] = value;
    }

    function getLastMinedBlock(
        uint256 key
    ) external view returns (QuantumPortalLib.Block memory) {
        return lastMinedBlock[key];
    }

    function setLastMinedBlock(
        uint256 key,
        QuantumPortalLib.Block calldata value
    ) external onlyMgr {
        lastMinedBlock[key] = value;
    }

    function getLastFinalizedBlock(
        uint256 key
    ) external view returns (QuantumPortalLib.Block memory) {
        return lastFinalizedBlock[key];
    }

    function setLastFinalizedBlock(
        uint256 key,
        QuantumPortalLib.Block calldata value
    ) external onlyMgr {
        lastFinalizedBlock[key] = value;
    }

    function setFinalization(
        uint256 key,
        IQuantumPortalLedgerMgr.FinalizationMetadata memory value
    ) external onlyMgr {
        finalizations[key] = value;
    }

    function pushFinalizationStake(
        uint256 key,
        IQuantumPortalLedgerMgr.FinalizerStake memory value
    ) external onlyMgr {
        finalizationStakes[key].push(value);
    }

    function getRemoteBalances(
        uint256 chainId,
        address token,
        address remoteContract
    ) external view returns (uint256) {
        return remoteBalances[chainId][token][remoteContract];
    }

    function setRemoteBalances(
        uint256 chainId,
        address token,
        address remoteContract,
        uint256 value
    ) external onlyLedger {
        remoteBalances[chainId][token][remoteContract] = value;
    }

    function setMgr(address _mgr) external onlyAdmin {
        mgr = _mgr;
    }

    function setLedger(address _ledger) external onlyAdmin {
        ledger = _ledger;
    }
}
