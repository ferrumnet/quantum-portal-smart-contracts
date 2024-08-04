// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {UUPSUpgradeable, Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IQuantumPortalLedgerMgr} from "../../../quantumPortal/poc/IQuantumPortalLedgerMgr.sol";
import {QuantumPortalLib} from "../../../quantumPortal/poc/QuantumPortalLib.sol";
import {WithAdmin} from "foundry-contracts/contracts/contracts-upgradeable/common/WithAdmin.sol";
import {WithGateway} from "./utils/WithGateway.sol";


contract QuantumPortalStateUpgradeable is Initializable, UUPSUpgradeable, WithAdmin, WithGateway {
    string public constant VERSION = "0.0.1";

    /// @custom:storage-location erc7201:ferrum.storage.quantumportalstate.001
    struct QuantumPortalStateStorageV001 {
        mapping(uint256 => IQuantumPortalLedgerMgr.LocalBlock) localBlocks;
        mapping(uint256 => QuantumPortalLib.RemoteTransaction[]) localBlockTransactions;
        mapping(uint256 => IQuantumPortalLedgerMgr.MinedBlock) minedBlocks;
        mapping(uint256 => QuantumPortalLib.RemoteTransaction[]) minedBlockTransactions;
        mapping(uint256 => QuantumPortalLib.Block) lastLocalBlock; // One block nonce per remote chain. txs local, to be run remotely
        mapping(uint256 => QuantumPortalLib.Block) lastMinedBlock; // One block nonce per remote chain. txs remote, to be run on here
        mapping(uint256 => QuantumPortalLib.Block) lastFinalizedBlock;
        mapping(uint256 => IQuantumPortalLedgerMgr.FinalizationMetadata) finalizations;
        mapping(uint256 => IQuantumPortalLedgerMgr.FinalizerStake[]) finalizationStakes;
        mapping(uint256 => mapping(address => mapping(address => uint256))) remoteBalances;
        address mgr;
        address ledger;
    }

    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.quantumportalstate.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant QuantumPortalStateStorageV001Location = 0x7ba18bc35c5bacc21dc6f03ccda4966cecb4a5730aa5a27939f833100d9a6400;

    function initialize(address initialOwner, address initialAdmin, address gateway) public initializer {
        __WithAdmin_init(initialOwner, initialAdmin);
        __WithGateway_init_unchained(gateway);
    }

    function _getQuantumPortalStateStorageV001() private pure returns (QuantumPortalStateStorageV001 storage $) {
        assembly {
            $.slot := QuantumPortalStateStorageV001Location
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyGateway {}

    /**
     * @notice Only allow the QP ledger manager to call
     */
    modifier onlyMgr() {
        require(msg.sender == mgr(), "QPS: Not allowed");
        _;
    }

    /**
     * @notice Only allow QP ledger to call
     */
    modifier onlyLedger() {
        require(msg.sender == ledger(), "QPS: Not allowed");
        _;
    }

    function mgr() public view returns (address) {
        return _getQuantumPortalStateStorageV001().mgr;
    }

    function ledger() public view returns (address) {
        return _getQuantumPortalStateStorageV001().ledger;
    }

    // constructor() Ownable(msg.sender) {}

    /**
     * @notice Get the local block
     * @param key The key
     */
    function getLocalBlocks(
        uint256 key
    ) external view returns (IQuantumPortalLedgerMgr.LocalBlock memory) {
        QuantumPortalStateStorageV001 storage $ = _getQuantumPortalStateStorageV001();
        return $.localBlocks[key];
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
        QuantumPortalStateStorageV001 storage $ = _getQuantumPortalStateStorageV001();
        $.localBlocks[key] = value;
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
        QuantumPortalStateStorageV001 storage $ = _getQuantumPortalStateStorageV001();
        $.localBlockTransactions[key].push(value);
    }

    /**
     * @notice Get the local block transaction length
     * @param key The key
     */
    function getLocalBlockTransactionLength(
        uint256 key
    ) external view returns (uint256) {
        QuantumPortalStateStorageV001 storage $ = _getQuantumPortalStateStorageV001();
        return $.localBlockTransactions[key].length;
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
        QuantumPortalStateStorageV001 storage $ = _getQuantumPortalStateStorageV001();
        return $.localBlockTransactions[key][idx];
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
        QuantumPortalStateStorageV001 storage $ = _getQuantumPortalStateStorageV001();
        value = $.localBlockTransactions[key];
    }

    /**
     * @notice Get the mined block
     * @param key The key
     */
    function getMinedBlock(
        uint256 key
    ) external view returns (IQuantumPortalLedgerMgr.MinedBlock memory) {
        QuantumPortalStateStorageV001 storage $ = _getQuantumPortalStateStorageV001();
        return $.minedBlocks[key];
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
        QuantumPortalStateStorageV001 storage $ = _getQuantumPortalStateStorageV001();
        $.minedBlocks[key] = value;
    }

    /**
     * @notice Set the mined block as invalid
     * @param key The block key
     */
    function setMinedBlockAsInvalid(uint256 key) external onlyMgr {
        QuantumPortalStateStorageV001 storage $ = _getQuantumPortalStateStorageV001();
        $.minedBlocks[key].invalidBlock = 1;
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
        QuantumPortalStateStorageV001 storage $ = _getQuantumPortalStateStorageV001();
        value = $.minedBlockTransactions[key];
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
        QuantumPortalStateStorageV001 storage $ = _getQuantumPortalStateStorageV001();
        $.minedBlockTransactions[key].push(value);
    }

    /**
     * @notice Get the last local block
     * @param key The block key
     */
    function getLastLocalBlock(
        uint256 key
    ) external view returns (QuantumPortalLib.Block memory) {
        QuantumPortalStateStorageV001 storage $ = _getQuantumPortalStateStorageV001();
        return $.lastLocalBlock[key];
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
        QuantumPortalStateStorageV001 storage $ = _getQuantumPortalStateStorageV001();
        $.lastLocalBlock[key] = value;
    }

    /**
     * @notice Get the last mined block
     * @param key The block key
     */
    function getLastMinedBlock(
        uint256 key
    ) external view returns (QuantumPortalLib.Block memory) {
        QuantumPortalStateStorageV001 storage $ = _getQuantumPortalStateStorageV001();
        return $.lastMinedBlock[key];
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
        QuantumPortalStateStorageV001 storage $ = _getQuantumPortalStateStorageV001();
        $.lastMinedBlock[key] = value;
    }

    /**
     * @notice Get the last finalized block
     * @param key The block key
     */
    function getLastFinalizedBlock(
        uint256 key
    ) external view returns (QuantumPortalLib.Block memory) {
        QuantumPortalStateStorageV001 storage $ = _getQuantumPortalStateStorageV001();
        return $.lastFinalizedBlock[key];
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
        QuantumPortalStateStorageV001 storage $ = _getQuantumPortalStateStorageV001();
        $.lastFinalizedBlock[key] = value;
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
        QuantumPortalStateStorageV001 storage $ = _getQuantumPortalStateStorageV001();
        $.finalizations[key] = value;
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
        QuantumPortalStateStorageV001 storage $ = _getQuantumPortalStateStorageV001();
        $.finalizationStakes[key].push(value);
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
        QuantumPortalStateStorageV001 storage $ = _getQuantumPortalStateStorageV001();
        return $.remoteBalances[chainId][token][remoteContract];
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
        QuantumPortalStateStorageV001 storage $ = _getQuantumPortalStateStorageV001();
        $.remoteBalances[chainId][token][remoteContract] = value;
    }

    /**
     * @notice Set the ledger manager
     * @param _mgr The ledger manager
     */
    function setMgr(address _mgr) external onlyAdmin {
        QuantumPortalStateStorageV001 storage $ = _getQuantumPortalStateStorageV001();
        $.mgr = _mgr;
    }

    /**
     * @notice Sets the ledger
     * @param _ledger The ledger
     */
    function setLedger(address _ledger) external onlyAdmin {
        QuantumPortalStateStorageV001 storage $ = _getQuantumPortalStateStorageV001();
        $.ledger = _ledger;
    }
}
