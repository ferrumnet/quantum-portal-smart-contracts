// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {UUPSUpgradeable, Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IVersioned} from "foundry-contracts/contracts/contracts/common/IVersioned.sol";
import {FullMath} from "foundry-contracts/contracts/contracts/math/FullMath.sol";
import {FixedPoint128} from "foundry-contracts/contracts/contracts/math/FixedPoint128.sol";
import {WithAdminUpgradeable} from "foundry-contracts/contracts/contracts-upgradeable/common/WithAdminUpgradeable.sol";
import {IQuantumPortalLedgerMgr} from "../../../quantumPortal/poc/IQuantumPortalLedgerMgr.sol";
import {IQuantumPortalMinerMgr} from "../../../quantumPortal/poc/poa/IQuantumPortalMinerMgr.sol";
import {IQuantumPortalAuthorityMgr} from "../../../quantumPortal/poc/poa/IQuantumPortalAuthorityMgr.sol";
import {IQuantumPortalFeeConvertor} from "../../../quantumPortal/poc/poa/IQuantumPortalFeeConvertor.sol";
import {IQuantumPortalMinerMembership} from "../../../quantumPortal/poc/poa/IQuantumPortalMinerMembership.sol";
import {IQuantumPortalStakeWithDelegate} from "../../../quantumPortal/poc/poa/stake/IQuantumPortalStakeWithDelegate.sol";
import {IQuantumPortalWorkPoolClient} from "../../../quantumPortal/poc/poa/IQuantumPortalWorkPoolClient.sol";
import {IQuantumPortalWorkPoolServer} from "../../../quantumPortal/poc/poa/IQuantumPortalWorkPoolServer.sol";
import {QuantumPortalMinerMgr} from "../../../quantumPortal/poc/poa/QuantumPortalMinerMgr.sol";
import {QuantumPortalLib} from "../../../quantumPortal/poc/QuantumPortalLib.sol";
import {PortalLedgerUpgradeable} from "./PortalLedgerUpgradeable.sol";
import {WithGatewayUpgradeable} from "./utils/WithGatewayUpgradeable.sol";

/**
 @notice Manages block generation.
 Each remote chain will have an independent block thread.
 Local blocks are virtual, meaning, they do not need to be implicitly generated.
 However, they are completely deterministic and updated as transactions are being added.
*/
contract QuantumPortalLedgerMgrUpgradeable is Initializable, UUPSUpgradeable, WithAdminUpgradeable, WithGatewayUpgradeable, IVersioned {
    uint256 constant FIX_TX_SIZE = 9 * 32;
    uint256 constant FIXED_REJECT_SIZE = 9 * 32;
    uint256 constant BLOCK_PERIOD = 2 minutes; // One block per two minutes?
    uint256 constant MAX_TXS_PER_BLOCK = 100; // Arbitraty number to prevent reaching the block gas limit 
    uint256 constant MAX_BLOCK_SIZE = 30_000_000 / 100; // Arbitrary number for max block size
    uint256 constant MAX_BLOCK_FOR_FINALIZATION = 10; // Maximum number of blocks for fin
    string public constant override VERSION = "000.001";
    uint256 immutable CHAIN_ID;

    /// @custom:storage-location erc7201:ferrum.storage.quantumportalledgermgr.001
    struct QuantumPortalLedgerMgrStorageV001 {
        uint256 minerMinimumStake;
        address minerMgr;
        address authorityMgr;
        address feeConvertor;
        address varFeeTarget;
        address fixedFeeTarget;
        PortalLedgerUpgradeable ledger;
        mapping(uint256 => IQuantumPortalLedgerMgr.LocalBlock) localBlocks;
        mapping(uint256 => QuantumPortalLib.RemoteTransaction[]) localBlockTransactions;
        mapping(uint256 => IQuantumPortalLedgerMgr.MinedBlock) minedBlocks;
        mapping(uint256 => QuantumPortalLib.RemoteTransaction[]) minedBlockTransactions;
        mapping(uint256 => QuantumPortalLib.Block) lastLocalBlock; // One block nonce per remote chain. txs local, to be run remotely
        mapping(uint256 => QuantumPortalLib.Block) lastMinedBlock; // One block nonce per remote chain. txs remote, to be run on here
        mapping(uint256 => QuantumPortalLib.Block) lastFinalizedBlock;
        mapping(uint256 => IQuantumPortalLedgerMgr.FinalizationMetadata) finalizations;
        mapping(uint256 => IQuantumPortalLedgerMgr.FinalizerStake[]) finalizationStakes;
    }

    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.quantumportalledgermgr.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant QuantumPortalLedgerMgrStorageV001Location = 0x9a3300396f5515e10506b7fb3808036138e108820c81acc3f0188e3656013600;

    function _getQuantumPortalLedgerMgrStorageV001() internal pure returns (QuantumPortalLedgerMgrStorageV001 storage $) {
        assembly {
            $.slot := QuantumPortalLedgerMgrStorageV001Location
        }
    }

    event RemoteTransactionRegistered(
        uint64 timestamp,
        address remoteContract,
        address sourceMsgSender,
        address sourceBeneficiary,
        address token,
        uint256 amount,
        bytes method,
        uint256 gas,
        uint256 fixedFee
    );

    event LocalBlockCreated(
        uint64 remoteChainId,
        uint64 nonce,
        uint64 timestamp
    );

    event MinedBlockCreated(
        bytes32 blockHash,
        address miner,
        uint256 stake,
        uint256 totalValue,
        QuantumPortalLib.Block blockMetadata
    );

    event FinalizedBlock(
        uint256 remoteChainId,
        uint256 blockNonce,
        uint256 timestamp
    );
    
    event FinalizedInvalidBlock(
        uint256 remoteChainId,
        uint256 blockNonce,
        uint256 timestamp
    );

    event FinalizedSnapshot(
        uint256 remoteChainId,
        uint256 startBlockNonce,
        uint256 endBlockNonce,
        address[] finalizers
    );

    /**
     * @notice Can only be called by ledger 
     */
    modifier onlyLedger() {
        require(msg.sender == address(ledger()), "QPLM: Not allowed");
        _;
    }

    constructor(uint256 overrideChainId) {
        CHAIN_ID = overrideChainId == 0 ? block.chainid : overrideChainId;
    }

    function initialize(address initialOwner, address initialAdmin, uint256 _minerMinimumStake, address gateway) public initializer {
        __WithAdmin_init(initialOwner, initialAdmin);
        __WithGateway_init_unchained(gateway);
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        $.minerMinimumStake = _minerMinimumStake;
    }

    function _authorizeUpgrade(address) internal override onlyGateway {}

    /**
     * @notice Restricted: Update ledger address
     * @param _ledger The ledger address
     */
    function updateLedger(address _ledger) external onlyAdmin {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        $.ledger = PortalLedgerUpgradeable(_ledger);
    }

    /**
     * @notice Get the local block
     * @param key The key
     */
    function getLocalBlocks(
        uint256 key
    ) public view returns (IQuantumPortalLedgerMgr.LocalBlock memory) {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        return $.localBlocks[key];
    }

    /**
     * @notice Sets the local block
     * @param key The key
     * @param value The block
     */
    function setLocalBlocks(
        uint256 key,
        IQuantumPortalLedgerMgr.LocalBlock memory value
    ) internal {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
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
    ) internal {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        $.localBlockTransactions[key].push(value);
    }

    /**
     * @notice Get the local block transaction length
     * @param key The key
     */
    function getLocalBlockTransactionLength(
        uint256 key
    ) public view returns (uint256) {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
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
    ) public view returns (QuantumPortalLib.RemoteTransaction memory) {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        return $.localBlockTransactions[key][idx];
    }

    /**
     * @notice Get all local block transactions
     * @param key The key
     */
    function getLocalBlockTransactions(
        uint256 key
    ) public view returns (QuantumPortalLib.RemoteTransaction[] memory value) {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        value = $.localBlockTransactions[key];
    }

    /**
     * @notice Get the mined block
     * @param key The key
     */
    function getMinedBlock(
        uint256 key
    ) public view returns (IQuantumPortalLedgerMgr.MinedBlock memory) {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        return $.minedBlocks[key];
    }

    /**
     * @notice Set the mined block
     * @param key The key
     * @param value The block
     */
    function setMinedBlock(
        uint256 key,
        IQuantumPortalLedgerMgr.MinedBlock memory value
    ) internal {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        $.minedBlocks[key] = value;
    }

    /**
     * @notice Set the mined block as invalid
     * @param key The block key
     */
    function setMinedBlockAsInvalid(uint256 key) internal {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        $.minedBlocks[key].invalidBlock = 1;
    }

    /**
     * @notice Get the mined block transactinos
     * @param key The block key
     */
    function getMinedBlockTransactions(
        uint256 key
    ) public view returns (QuantumPortalLib.RemoteTransaction[] memory value) {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
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
    ) internal {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        $.minedBlockTransactions[key].push(value);
    }

    /**
     * @notice Get the last local block
     * @param key The block key
     */
    function getLastLocalBlock(
        uint256 key
    ) public view returns (QuantumPortalLib.Block memory) {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        return $.lastLocalBlock[key];
    }

    /**
     * @notice Set the last local block
     * @param key The block key
     * @param value The block
     */
    function setLastLocalBlock(
        uint256 key,
        QuantumPortalLib.Block memory value
    ) internal {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        $.lastLocalBlock[key] = value;
    }

    /**
     * @notice Get the last mined block
     * @param key The block key
     */
    function getLastMinedBlock(
        uint256 key
    ) public view returns (QuantumPortalLib.Block memory) {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        return $.lastMinedBlock[key];
    }

    /**
     * @notice Sets the last mined block
     * @param key The key
     * @param value The block
     */
    function setLastMinedBlock(
        uint256 key,
        QuantumPortalLib.Block memory value
    ) internal {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        $.lastMinedBlock[key] = value;
    }

    /**
     * @notice Get the last finalized block
     * @param key The block key
     */
    function getLastFinalizedBlock(
        uint256 key
    ) public view returns (QuantumPortalLib.Block memory) {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        return $.lastFinalizedBlock[key];
    }

    /**
     * @notice Sets the last finalized block
     * @param key The block key
     * @param value The block
     */
    function setLastFinalizedBlock(
        uint256 key,
        QuantumPortalLib.Block memory value
    ) internal {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
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
    ) internal {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
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
    ) internal {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        $.finalizationStakes[key].push(value);
    }

    /**
     * @notice Restricted: update the authority manager
     * @param _authorityMgr The autority manager
     */
    function updateAuthorityMgr(address _authorityMgr) external onlyAdmin {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        $.authorityMgr = _authorityMgr;
    }

    /**
     * @notice Updates the miner manager
     * @param _minerMgr The miner manager
     */
    function updateMinerMgr(address _minerMgr) external onlyAdmin {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        $.minerMgr = _minerMgr;
    }

    /**
     * @notice Update the fee convertor
     * @param _feeConvertor The fee convertor address
     */
    function updateFeeConvertor(address _feeConvertor) external onlyAdmin {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        $.feeConvertor = _feeConvertor;
    }

    /**
     * @notice Restricted: Updates the fee target
     * @param _varFeeTarget The variable fee target
     * @param _fixedFeeTarget The fixed fee target
     */
    function updateFeeTargets(
        address _varFeeTarget,
        address _fixedFeeTarget
    ) external onlyAdmin {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        $.varFeeTarget = _varFeeTarget;
        $.fixedFeeTarget = _fixedFeeTarget;
    }

    /**
     * @notice Restricted: Update the miner minimum stake
     * @param amount The amount to mine
     */
    function updateMinerMinimumStake(uint256 amount) external onlyAdmin {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        $.minerMinimumStake = amount;
    }

    /**
     * @notice Calculate the fixed fee.
     * @param targetChainId The target chain ID
     * @param varSize The variable size
     */
    function calculateFixedFee(
        uint256 targetChainId,
        uint256 varSize
    ) external view returns (uint256) {
        return _calculateFixedFee(targetChainId, varSize);
    }

    /**
     * @notice Calculate the fixed fee
     * @param targetChainId The target chainID
     * @param varSize The variable size
     */
    function _calculateFixedFee(
        uint256 targetChainId,
        uint256 varSize
    ) private view returns (uint256) {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        return
            IQuantumPortalFeeConvertor($.feeConvertor).targetChainFixedFee(
                targetChainId,
                FIX_TX_SIZE + varSize
            );
    }

    /**
     * @notice Register a remote transaction. Adds a tx to the pool. Moves the block nonce if new block
     *     is warranted
     * @param remoteChainId The remote chain ID
     * @param remoteContract The remote contract
     * @param msgSender The message sender
     * @param beneficiary The beneficicary
     * @param token The token
     * @param amount The amount
     * @param method The method
     */
    function registerTransaction(
        uint64 remoteChainId,
        address remoteContract,
        address msgSender,
        address beneficiary,
        address token,
        uint256 amount,
        bytes memory method
    ) external onlyLedger {
        require(
            remoteContract != QuantumPortalLib.FRAUD_PROOF,
            "QPLM: Invalid remoteContract"
        );
        _registerTransaction(
            remoteChainId,
            remoteContract,
            msgSender,
            beneficiary,
            token,
            amount,
            method
        );
    }

    /**
     * @notice Sumbits a fraud prood. Fraud proof consisted of a signed block,
     *     by a miner from a remote chain, that does not match a local
     *     block.
     * @param minedOnChainId The chain that includes the fradulent block
     * @param localBlockNonce The block nonce
     * @param localBlockTimestamp The block timestamp
     * @param transactions List of transactions in the block
     * @param salt The salt used to sign the block
     * @param expiry The expiry of the signer signature
     * @param multiSignature The signature
     * @param rewardReceiver Address to receive the rewards
     */
    function submitFraudProof(
        uint64 minedOnChainId,
        uint64 localBlockNonce,
        uint64 localBlockTimestamp,
        QuantumPortalLib.RemoteTransaction[] memory transactions,
        bytes32 salt,
        uint64 expiry,
        bytes memory multiSignature,
        address rewardReceiver
    ) external {
        // We don't know the MinerMgr contract address on the remote chain, so we cannot extract that the
        // fragulent block is signed by the claimed "fradulentMiner".
        // This is not a problem because we will check this before accepting the fraud proof tx on the other side
        // Here, we only confirm that the presented block is fradulent.

        bool fraudDetected;
        bytes memory method;
        bytes32 blockHash;
        {
            uint256 key = blockIdx(uint64(CHAIN_ID), localBlockNonce);
            QuantumPortalLib.Block memory _block = getLocalBlocks(key).metadata;
            fraudDetected =
                _block.chainId != minedOnChainId ||
                _block.nonce != localBlockNonce ||
                _block.timestamp != localBlockTimestamp ||
                transactions.length !=
                getLocalBlockTransactionLength(key);
            blockHash = _calculateBlockHash(
                uint64(CHAIN_ID),
                localBlockNonce,
                transactions
            );
            method = abi.encode(
                uint256(blockHash),
                localBlockNonce,
                salt,
                expiry,
                multiSignature
            );
            if (!fraudDetected) {
                for (uint i = 0; i < transactions.length; i++) {
                    QuantumPortalLib.RemoteTransaction memory t = getLocalBlockTransaction(key, i);
                    fraudDetected =
                        fraudDetected ||
                        (!QuantumPortalLib.txEquals(t, transactions[i]));
                    if (fraudDetected) {
                        break;
                    }
                }
            }
        }
        if (fraudDetected) {
            _registerTransaction(
                minedOnChainId,
                QuantumPortalLib.FRAUD_PROOF,
                address(this),
                rewardReceiver,
                address(0),
                0,
                method
            );
        }
    }

    /**
     @notice A local block is ready based on the lastest block time. This logic can be changed in future.
     @param chainId The chain ID.
     */
    function isLocalBlockReady(uint64 chainId) external view returns (bool) {
        return _isLocalBlockReady(getLastLocalBlock(chainId));
    }

    /**
     * @notice Returns the last remote mined block
     * @param chainId The chain ID
     */
    function lastRemoteMinedBlock(
        uint64 chainId
    ) external view returns (QuantumPortalLib.Block memory _block) {
        _block = getLastMinedBlock(chainId);
    }

    /**
     * @notice Returns the minde block given nonce
     * @param chainId The chain ID
     * @param blockNonce The block nonce
     * @return b The block
     * @return txs List of transaction
     */
    function minedBlockByNonce(
        uint64 chainId,
        uint64 blockNonce
    )
        external
        view
        returns (
            IQuantumPortalLedgerMgr.MinedBlock memory b,
            QuantumPortalLib.RemoteTransaction[] memory txs
        )
    {
        uint256 key = blockIdx(chainId, blockNonce);
        b = getMinedBlock(key);
        txs = getMinedBlockTransactions(key);
    }

    /**
     * @notice Return the local block given the nonce
     * @param chainId The chain ID
     * @param blockNonce The block nonce
     * @return The local block
     * @return List of transactions in the block
     */
    function localBlockByNonce(
        uint64 chainId,
        uint64 blockNonce
    )
        external
        view
        returns (
            IQuantumPortalLedgerMgr.LocalBlock memory,
            QuantumPortalLib.RemoteTransaction[] memory
        )
    {
        uint256 key = blockIdx(chainId, blockNonce);
        return (
            getLocalBlocks(key),
            getLocalBlockTransactions(key)
        );
    }

    /**
     * @notice Registers self as a miner
     */
    function registerMiner() external {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        uint256 stake = stakeOf(msg.sender);
        require(stake >= $.minerMinimumStake, "QPLM: not enough stake");
        IQuantumPortalMinerMembership($.minerMgr).registerMiner(msg.sender);
    }

    bytes32 constant MINE_REMOTE_BLOCK =
        keccak256(
            "MineRemoteBlock(uint64 remoteChainId,uint64 blockNonce,bytes32 transactions,bytes32 salt, uint64 expiry)"
        );

    /**
     @notice To mine a block we currently follow this algorithm:
        - Make sure this is right block to mine (last nonce mined, this nonce not mined)
        - Make sure the miner is allowed
        - Calculate the block hash

        Necessary improvements:
        - Allow multiple blocks to be mined (per remote chain), and honest miners to follow the valid block
        - For now, we just assume all miners are honest.
     * @param remoteChainId The remote chain ID
     * @param blockNonce The block nonce
     * @param transactions List of transactions
     * @param salt The salt
     * @param expiry Signature expiry
     * @param multiSignature The signature
     */
    function mineRemoteBlock(
        uint64 remoteChainId,
        uint64 blockNonce,
        QuantumPortalLib.RemoteTransaction[] memory transactions,
        bytes32 salt,
        uint64 expiry,
        bytes memory multiSignature
    ) external {
        
        require(remoteChainId != 0, "QPLM: remoteChainId required");
        {
            uint256 lastNonce = getLastMinedBlock(remoteChainId).nonce;
            require(
                blockNonce == lastNonce + 1,
                "QPLM: cannot jump or retrace nonce"
            );
        }
        require(transactions.length <= MAX_TXS_PER_BLOCK, "QPLM: too many txs");

        IQuantumPortalLedgerMgr.MinedBlock memory mb;

        { // Stack
            bytes32 blockHash = _calculateBlockHash(
                remoteChainId,
                blockNonce,
                transactions
            );

            uint256 totalValue = 0;
            uint256 totalSize = 0;
            for (uint i = 0; i < transactions.length; i++) {
                totalValue += _transactionValue(transactions[i]);
                for (uint j=0; j < transactions[i].methods.length; j++) {
                    totalSize += transactions[i].methods[j].length;
                }
            }

            require(totalSize <= MAX_BLOCK_SIZE, "QPLM: block too large");

            address miner;
            uint256 minerStake;
            { // Sub stack
                // Validate miner
                IQuantumPortalMinerMgr.ValidationResult validationResult;
                (
                    validationResult,
                    miner,
                    minerStake
                ) = IQuantumPortalMinerMgr(minerMgr()).verifyMinerSignature(
                    blockHash,
                    salt,
                    expiry,
                    multiSignature,
                    totalValue,
                    minerMinimumStake()
                );

                if (
                    validationResult !=
                    IQuantumPortalMinerMgr.ValidationResult.Valid
                ) {
                    require(
                        validationResult !=
                            IQuantumPortalMinerMgr.ValidationResult.NotEnoughStake,
                        "QPLM: miner has not enough stake"
                    );
                    revert("QPLM: miner signature cannot be verified");
                }
            } // End sub stack

            {
                uint256 remoteBlockTimestamp = transactions[
                    transactions.length - 1
                ].timestamp;
                require(
                    IQuantumPortalMinerMembership(minerMgr()).selectMiner(
                        miner,
                        blockHash,
                        remoteBlockTimestamp
                    ),
                    "QPLM: mining out of order"
                );
            }

            IQuantumPortalWorkPoolClient(minerMgr()).registerWork(
                remoteChainId,
                miner,
                FIX_TX_SIZE * transactions.length + totalSize,
                blockNonce
            );
            QuantumPortalLib.Block memory blockMetadata = QuantumPortalLib
                .Block({
                    chainId: remoteChainId,
                    nonce: blockNonce,
                    timestamp: uint64(block.timestamp)
                });
            setLastMinedBlock(remoteChainId, blockMetadata);
            
            mb = IQuantumPortalLedgerMgr.MinedBlock({
                blockHash: blockHash,
                miner: msg.sender,
                invalidBlock: 0,
                stake: minerStake,
                totalValue: totalValue,
                blockMetadata: blockMetadata
            });
            emit MinedBlockCreated(
                blockHash,
                msg.sender,
                minerStake,
                totalValue,
                blockMetadata
            );
        } // End stack
        
        uint256 key = blockIdx(remoteChainId, blockNonce);
        setMinedBlock(key, mb);
        for (uint i = 0; i < transactions.length; i++) {
            pushMinedBlockTransactions(key, transactions[i]);
        }
    }

    bytes32 constant FINALIZE_METHOD =
        keccak256(
            "Finalize(uint256 remoteChainId,uint256 blockNonce,uint256[] invalidBlockNonces,bytes32 salt,uint64 expiry)"
        );

    /**
     * @notice Finalize unfinalized blocks
     * @param remoteChainId The remote chain ID
     * @param blockNonce The block nonce
     * @param invalidBlockNonces List of invalid blocks
     * @param salt The salt
     * @param expiry Signature expiry
     * @param multiSignature The signature
     */
    function finalize(
        uint256 remoteChainId,
        uint256 blockNonce,
        uint256[] memory invalidBlockNonces,
        bytes32 salt,
        uint64 expiry,
        bytes memory multiSignature
    ) external {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        bytes32 msgHash = keccak256(
            abi.encode(
                FINALIZE_METHOD,
                remoteChainId,
                blockNonce,
                invalidBlockNonces,
                salt,
                expiry
            )
        );
        
        address[] memory finalizers = IQuantumPortalAuthorityMgr($.authorityMgr).validateAuthoritySignature(
            IQuantumPortalAuthorityMgr.Action.FINALIZE,
            msgHash,
            salt,
            expiry,
            multiSignature
        );
        doFinalize(
            remoteChainId,
            blockNonce,
            invalidBlockNonces,
            msgHash,
            finalizers
        );
    }

    /**
     * @notice Gets the block index
     * @param chainId The chain ID
     * @param nonce The nonce
     */
    function getBlockIdx(
        uint64 chainId,
        uint64 nonce
    ) external pure returns (uint256) {
        return blockIdx(chainId, nonce);
    }

    /**
     @notice Helper method for client applications to calculate the block hash.
     @param remoteChainId The remote chain ID
     @param blockNonce The block nonce
     @param transactions Remote transactions in the block
     */
    function calculateBlockHash(
        uint64 remoteChainId,
        uint64 blockNonce,
        QuantumPortalLib.RemoteTransaction[] memory transactions
    ) external pure returns (bytes32) {
        return _calculateBlockHash(remoteChainId, blockNonce, transactions);
    }

    /**
     * @notice Register a remote transaction. Adds a tx to the pool. Moves the block nonce if new block
     *     is warranted
     * @param remoteChainId The remote chain ID
     * @param remoteContract The remote contract
     * @param msgSender The message sender
     * @param beneficiary The beneficicary
     * @param token The token
     * @param amount The amount
     * @param method The method
     */
    function _registerTransaction(
        uint64 remoteChainId,
        address remoteContract,
        address msgSender,
        address beneficiary,
        address token,
        uint256 amount,
        bytes memory method
    ) internal {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        // We can allow self chain mining
        // require(remoteChainId != CHAIN_ID, "QPLM: bad remoteChainId");
        QuantumPortalLib.Block memory b = getLastLocalBlock(
            remoteChainId
        );
        uint256 key = blockIdx(remoteChainId, b.nonce);
        uint256 fixedFee = _calculateFixedFee(remoteChainId, method.length);
        bytes[] memory methods = new bytes[](1);
        methods[0] = method;
        QuantumPortalLib.RemoteTransaction memory remoteTx = QuantumPortalLib
            .RemoteTransaction({
                timestamp: uint64(block.timestamp),
                remoteContract: remoteContract,
                sourceMsgSender: msgSender,
                sourceBeneficiary: beneficiary,
                token: token,
                amount: amount,
                methods: method.length != 0 ? methods : new bytes[](0),
                gas: 0,
                fixedFee: fixedFee
            });
        if (_isLocalBlockReady(b)) {
            b.nonce++;
            b.timestamp = uint64(block.timestamp);
            b.chainId = remoteChainId;
            setLastLocalBlock(remoteChainId, b);
            key = blockIdx(remoteChainId, b.nonce);
            setLocalBlocks(
                key,
                IQuantumPortalLedgerMgr.LocalBlock({metadata: b})
            );
            emit LocalBlockCreated(b.chainId, b.nonce, b.timestamp);
        }

        uint256 varFee = IQuantumPortalWorkPoolServer($.minerMgr).collectFee(
            remoteChainId,
            b.nonce,
            fixedFee
        );
        remoteTx.gas = varFee;
        pushLocalBlockTransactions(key, remoteTx);
        emit RemoteTransactionRegistered(
            remoteTx.timestamp,
            remoteTx.remoteContract,
            remoteTx.sourceMsgSender,
            remoteTx.sourceBeneficiary,
            remoteTx.token,
            remoteTx.amount,
            method,
            remoteTx.gas,
            remoteTx.fixedFee
        );
    }

    /**
     * @notice Execute the finalization
     * @param remoteChainId The remote chain ID
     * @param blockNonce The block nonce
     * @param invalidNoncesOrdered List of invalid blocks. Must be ordered
     * @param msgHash Hash of finalization request
     * @param finalizers List of finalizers
     */
    function doFinalize(
        uint256 remoteChainId,
        uint256 blockNonce,
        uint256[] memory invalidNoncesOrdered,
        bytes32 msgHash,
        address[] memory finalizers
    ) internal {
        {
            QuantumPortalLib.Block memory lastMinedB = getLastMinedBlock(
                remoteChainId
            );
            require(lastMinedB.chainId != 0, "QPLM: No block is mined");
            require(blockNonce <= lastMinedB.nonce, "QPLM: nonce not mined");
        }

        QuantumPortalLib.Block memory lastFinB = getLastFinalizedBlock(
            remoteChainId
        );
        require(
            lastFinB.chainId == 0 || // First time finalizing
                blockNonce > lastFinB.nonce,
            "QPLM: already finalized"
        );
        uint256 finalizeFrom = lastFinB.chainId == 0 ? 0 : lastFinB.nonce + 1;
        uint256 blockCount = blockNonce - finalizeFrom;
        require(blockCount <= MAX_BLOCK_FOR_FINALIZATION, "QPLM: too many blocks");
        require(invalidNoncesOrdered.length <= blockCount, "QPLM: invalid nonces too large");
        if (invalidNoncesOrdered.length > 1) {
            for (uint i = 1; i < invalidNoncesOrdered.length; i++) {
                require(
                    invalidNoncesOrdered[i] > invalidNoncesOrdered[i - 1],
                    "QPLM: invalidNonces not ordered"
                );
            }
        }
        uint256 finalizedKey = blockIdx(
            uint64(remoteChainId),
            uint64(blockNonce)
        );

        (uint256 totalMinedWork, uint256 totalVarWork) = doFinalizeLoop(
            remoteChainId,
            finalizeFrom,
            blockNonce,
            invalidNoncesOrdered,
            msgHash,
            finalizedKey
        );

        IQuantumPortalWorkPoolClient(minerMgr()).registerWork(
            remoteChainId,
            msg.sender,
            totalMinedWork,
            blockNonce
        );
        IQuantumPortalWorkPoolClient(authorityMgr()).registerWork(
            remoteChainId,
            msg.sender,
            totalVarWork,
            blockNonce
        );

        // Disabled the stake log for gas saving. This can be done off-chain
        // for (uint i = 0; i < finalizers.length; i++) {
        //     pushFinalizationStake(
        //         finalizedKey,
        //         IQuantumPortalLedgerMgr.FinalizerStake({
        //             finalizer: finalizers[i],
        //             staked: stakeOf(finalizers[i])
        //         })
        //     );
        // }
        setLastFinalizedBlock(
            remoteChainId,
            QuantumPortalLib.Block({
                chainId: uint64(remoteChainId),
                nonce: uint64(blockNonce),
                timestamp: uint64(block.timestamp)
            })
        );
        emit FinalizedSnapshot(
            remoteChainId,
            finalizeFrom,
            blockNonce,
            finalizers
        );
    }

    /**
     * @notice Do the finalization in a loop
     * @param remoteChainId The remote chain ID
     * @param fromNonce The starting nonce
     * @param toNonce The ending nonce
     * @param invalids List of invalid blocks
     * @param msgHash The hash of finalization message
     * @param finalizedKey The key of finalized block
     * @return totalMinedWork Total mined work
     * @return totalVarWork Total variable work
     */
    function doFinalizeLoop(
        uint256 remoteChainId,
        uint256 fromNonce,
        uint256 toNonce,
        uint256[] memory invalids,
        bytes32 msgHash,
        uint256 finalizedKey
    ) internal returns (uint256 totalMinedWork, uint256 totalVarWork) {
        bytes32 finHash = 0;
        uint256 invalidIdx = 0;
        uint256 totalBlockStake = 0;

        for (uint i = fromNonce; i <= toNonce; i++) {
            uint256 bkey = blockIdx(uint64(remoteChainId), uint64(i));
            // We are XOR ing the block hashes. AS the hashes are random, this will not be theoretically secure
            // but as we have a small finite list of items that can be played with, (e.g. block hashes form a range of epocs)
            // a simple xor is enough. The finHash is only used for sanity check offline, so it is not critical information
            finHash = finHash ^ getMinedBlock(bkey).blockHash;
            totalBlockStake += getMinedBlock(bkey).stake;
            if (
                invalids.length != 0 &&
                i == invalids[invalidIdx] &&
                invalids.length > invalidIdx
            ) {
                // This is an inbvalid block
                uint256 minedWork = rejectBlock(bkey);
                totalMinedWork += minedWork;
                invalidIdx++;
                emit FinalizedInvalidBlock(
                    remoteChainId,
                    toNonce,
                    block.timestamp
                );
            } else {
                (uint256 minedWork, uint256 varWork) = executeBlock(bkey);
                totalMinedWork += minedWork;
                totalVarWork += varWork;
                emit FinalizedBlock(remoteChainId, toNonce, block.timestamp);
            }
        }

        IQuantumPortalLedgerMgr.FinalizationMetadata
            memory fin = IQuantumPortalLedgerMgr.FinalizationMetadata({
                executor: msg.sender,
                finalizedBlocksHash: finHash,
                finalizationHash: msgHash,
                totalBlockStake: totalBlockStake
            });
        setFinalization(finalizedKey, fin);
    }

    /**
     @notice Goes through every transaction and executes it. By the end charges fees for the miners and 
        cost of running
     @param key The block key
     */
    function executeBlock(
        uint256 key
    ) internal returns (uint256 totalMineWork, uint256 totalVarWork) {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        IQuantumPortalLedgerMgr.MinedBlock memory b = getMinedBlock(key);
        PortalLedgerUpgradeable qp = PortalLedgerUpgradeable($.ledger);
        uint256 gasPrice = IQuantumPortalFeeConvertor($.feeConvertor)
            .localChainGasTokenPriceX128();
        QuantumPortalLib.RemoteTransaction[] memory transactions = getMinedBlockTransactions(key);
        for (uint i = 0; i < transactions.length; i++) {
            QuantumPortalLib.RemoteTransaction memory t = transactions[i];
            totalMineWork += FIX_TX_SIZE;
            for (uint j=0; j<t.methods.length; j++) {
                totalMineWork += t.methods[j].length;
            }
            uint256 txGas = FullMath.mulDiv(
                gasPrice,
                t.gas,
                FixedPoint128.Q128
            );
            txGas = txGas / tx.gasprice;
            uint256 baseGasUsed;
            if (t.remoteContract == QuantumPortalLib.FRAUD_PROOF) {
                // What if the FraudProof is fradulent itself?
                // Can msgSender be tempered with? Only if the miner is malicous. In that case the whole tx can be fabricated
                // so there is no benefit in checking the msgSender.
                // A malicous miner can technically submit a fake Fraud Proof to hurt other miners, however, they will
                // be caught and their stake will be slashed. Also, the finalizers are expected to validate blocks before finalizing.
                baseGasUsed = processFraudProof(t, b.blockMetadata.chainId);
            } else {
                baseGasUsed = qp.executeRemoteTransaction(
                    i,
                    b.blockMetadata,
                    t,
                    txGas
                );
            }
            totalVarWork += baseGasUsed;
            // We are not refunding extra gas. Maybe in future.
        }
        qp.clearContext();
    }

    /**
     * @notice Rejects the block
     * @param key Block key
     */
    function rejectBlock(uint256 key) internal returns (uint256 totalMineWork) {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        setMinedBlockAsInvalid(key);
        IQuantumPortalLedgerMgr.MinedBlock memory b = getMinedBlock(key);
        PortalLedgerUpgradeable qp = PortalLedgerUpgradeable($.ledger);
        uint256 gasPrice = IQuantumPortalFeeConvertor($.feeConvertor)
            .localChainGasTokenPriceX128();
        QuantumPortalLib.RemoteTransaction[] memory transactions = getMinedBlockTransactions(key);
        for (uint i = 0; i < transactions.length; i++) {
            QuantumPortalLib.RemoteTransaction memory t = transactions[i];
            totalMineWork += FIX_TX_SIZE;
            for (uint j=0; j < t.methods.length; j++) {
                totalMineWork += t.methods[j].length;
            }
            totalMineWork += FIXED_REJECT_SIZE;
            uint256 txGas = FullMath.mulDiv(
                gasPrice,
                t.gas,
                FixedPoint128.Q128
            );
            txGas = txGas / tx.gasprice;
            qp.rejectRemoteTransaction(b.blockMetadata.chainId, t);
        }
        qp.clearContext();
    }

    /**
     * @notice Processes a fraud proof
     * @param t The fraud proof transaction
     * @param sourceChainId The source chain ID
     */
    function processFraudProof(
        QuantumPortalLib.RemoteTransaction memory t,
        uint64 sourceChainId
    ) internal returns (uint256 gasUsed) {
        uint preGas = gasleft();
        // Ensure the block is actually mined.
        (
            bytes32 blockHash,
            uint256 nonce,
            bytes32 salt,
            uint64 expiry,
            bytes memory multiSignature
        ) = abi.decode(t.methods[0], (bytes32, uint256, bytes32, uint64, bytes));
        uint256 key = blockIdx(sourceChainId, uint64(nonce));
        IQuantumPortalLedgerMgr.MinedBlock memory b = getMinedBlock(key);
        if (b.blockHash == blockHash) {
            // Block is indeed mined
            // First extract the miner address from the signature
            address fradulentMiner = IQuantumPortalMinerMgr(minerMgr())
                .extractMinerAddress(b.blockHash, salt, expiry, multiSignature);

            // Slash fradulent miner's funds
            // And pay the reward to tx.benefciary
            IQuantumPortalMinerMgr(minerMgr()).slashMinerForFraud(
                fradulentMiner,
                blockHash,
                t.sourceBeneficiary
            );
        }
        uint postGas = gasleft();
        gasUsed = preGas - postGas;
    }

    /**
     @notice Returns the token price vs FRM (fixed point 128).
        Note: this feature is used to estimate the transaction value for value-contrained PoS.
        Not implemented yet. Therefore we are returning 0 at this point
     @param token The token
     @return The price
     */
    function tokenPriceX128(
        address token
    ) internal view virtual returns (uint256) {
        return 0;
    }

    /**
     @notice Returns available stake of the staker.
     @param worker The worker address
     @return The available staked amount
     */
    function stakeOf(address worker) internal virtual returns (uint256) {
        QuantumPortalLedgerMgrStorageV001 storage $ = _getQuantumPortalLedgerMgrStorageV001();
        address _stake = IQuantumPortalMinerMgr($.minerMgr).miningStake();
        return IQuantumPortalStakeWithDelegate(_stake).stakeOfDelegate(worker);
    }

    /**
     * @notice Save gas by packing a multidic key into one key
     * @param chainId The chain ID
     * @param nonce The nonce
     */
    function blockIdx(
        uint64 chainId,
        uint64 nonce
    ) private pure returns (uint256) {
        return (uint256(chainId) << 64) + nonce;
    }

    /**
     * @notice Identifies if we are ready for a new block
     * @param b The block
     */
    function _isLocalBlockReady(
        QuantumPortalLib.Block memory b
    ) private view returns (bool) {
        return (block.timestamp - b.timestamp) >= BLOCK_PERIOD;
    }

    /**
     * @notice Returns a unique block hash.
     * @param remoteChainId The remote chain ID
     * @param blockNonce The block nonce
     * @param transactions List of transactions
     */
    function _calculateBlockHash(
        uint64 remoteChainId,
        uint64 blockNonce,
        QuantumPortalLib.RemoteTransaction[] memory transactions
    ) private pure returns (bytes32) {
        return keccak256(abi.encode(remoteChainId, blockNonce, transactions));
    }

    /**
     * @notice Calcualtes the transaction value
     * @param transaction The transaction
     */
    function _transactionValue(
        QuantumPortalLib.RemoteTransaction memory transaction
    ) private view returns (uint256 value) {
        value += FullMath.mulDiv(
            tokenPriceX128(transaction.token),
            transaction.amount,
            FixedPoint128.Q128
        );
    }

    function minerMgr() public view returns (address) {
        return  _getQuantumPortalLedgerMgrStorageV001().minerMgr;
    }

    function minerMinimumStake() public view returns (uint256) {
        return _getQuantumPortalLedgerMgrStorageV001().minerMinimumStake;
    }

    function authorityMgr() public view returns (address) {
        return _getQuantumPortalLedgerMgrStorageV001().authorityMgr;
    }

    function ledger() public view returns (PortalLedgerUpgradeable) {
        return _getQuantumPortalLedgerMgrStorageV001().ledger;
    }

    function feeConvertor() public view returns (address) {
        return _getQuantumPortalLedgerMgrStorageV001().feeConvertor;
    }

    function varFeeTarget() public view returns (address) {
        return _getQuantumPortalLedgerMgrStorageV001().varFeeTarget;
    }

    function fixedFeeTarget() public view returns (address) {
        return _getQuantumPortalLedgerMgrStorageV001().fixedFeeTarget;
    }
}

contract QuantumPortalLedgerMgrImplUpgradeable is QuantumPortalLedgerMgrUpgradeable {
    constructor() QuantumPortalLedgerMgrUpgradeable(0) {}
}
