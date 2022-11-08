// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IQuantumPortalLedgerMgr.sol";
import "./poa/QuantumPortalMinerMgr.sol";
import "../../common/IVersioned.sol";
import "../../common/math/FullMath.sol";
import "../../common/math/FixedPoint128.sol";
import "../../common/WithAdmin.sol";
import "./QuantumPortalLib.sol";
import "./PortalLedger.sol";

import "hardhat/console.sol";

/**
 @notice Manages block generation.
 Each remote chain will have an independent block thread.
 Local blocks are virtual, meaning, they do not need to be implicitly generate.
 However, they are completely deterministic and updated as transactions are being added.
*/
contract QuantumPortalLedgerMgr is WithAdmin, IQuantumPortalLedgerMgr, IVersioned {
    struct LocalBlock {
        QuantumPortalLib.Block metadata;
    }

    struct MinedBlock {
        bytes32 blockHash;
        address miner;
        uint256 stake;
        uint256 totalValue;
        QuantumPortalLib.Block blockMetadata;
    }

    struct FinalizerStake { // TODO: Compress
        address finalizer;
        uint256 staked;
    }

    struct FinalizationMetadata {
        address executor;
        bytes32 finalizedBlocksHash;
        bytes32 finalizersHash;
        uint256 totalBlockStake;
    }

	string constant public override VERSION = "000.001";
    uint256 constant BLOCK_PERIOD = 60; // One block per minute?
    uint256 immutable CHAIN_ID;
    uint256 public minerMinimumStake = 10**18 * 1000000; // Minimum 1M tokens to become miner
    mapping(uint256 => LocalBlock) public localBlocks;
    mapping(uint256 => QuantumPortalLib.RemoteTransaction[]) public localBlockTransactions;
    mapping(uint256 => MinedBlock) public minedBlocks;
    mapping(uint256 => QuantumPortalLib.RemoteTransaction[]) public minedBlockTransactions;
    mapping(bytes32 => address[]) public authorityFinalizers; // This is used in case stake was not enogh or max security required
    mapping(uint256 => QuantumPortalLib.Block) public lastLocalBlock; // One block nonce per remote chain. txs local, to be run remotely
    mapping(uint256 => QuantumPortalLib.Block) public lastMinedBlock; // One block nonce per remote chain. txs remote, to be run on here
    mapping(uint256 => QuantumPortalLib.Block) public lastFinalizedBlock;
    mapping(uint256 => FinalizationMetadata) public finalizations;
    mapping(uint256 => FinalizerStake[]) public finalizationStakes;
    address public ledger;
    address public minerMgr;

    modifier onlyLedger() {
        require(msg.sender == ledger, "QPLM: Not allowed");
        _;
    }

    function updateLedger(address _ledger) external onlyAdmin {
        ledger = _ledger;
    }

    constructor(uint256 overrideChainId) {
        CHAIN_ID = overrideChainId == 0 ? block.chainid : overrideChainId;
    }

    /**
     @notice Adds a tx to the pool. Moves the block nonce if new block
     is warranted.
     TODO: Have a minimum amount for gas based on the remoteChainId.
        This can be done through, 1) the price of target core token (proxy)
        on the amm. And minimum tx fee in the target token basis
     */
    function registerTransaction(
        uint64 remoteChainId,
        address remoteContract,
        address msgSender,
        address beneficiary,
        address token,
        uint256 amount,
        uint256 gas,
        bytes memory method
    ) external override onlyLedger {
        require(remoteChainId != CHAIN_ID, "QPLM: bad remoteChainId");
        QuantumPortalLib.Block memory b = lastLocalBlock[remoteChainId];
        console.log("ORIGINAL NONCE IS", b.nonce);
        uint256 key = blockIdx(remoteChainId, b.nonce);
        QuantumPortalLib.RemoteTransaction memory remoteTx = QuantumPortalLib.RemoteTransaction({
            timestamp: uint64(block.timestamp),
            remoteContract: remoteContract,
            sourceMsgSender: msgSender,
            sourceBeneficiary: beneficiary,
            token: token,
            amount: amount,
            method: method,
            gas: gas
        });
        if (_isLocalBlockReady(b)) {
            b.nonce ++;
            b.timestamp = uint64(block.timestamp);
            b.chainId = remoteChainId;
            lastLocalBlock[remoteChainId] = b;
            key = blockIdx(remoteChainId, b.nonce);
            localBlocks[key] = LocalBlock({
                metadata: b
            });
        }
        localBlockTransactions[key].push(remoteTx);
    }

    /**
     @notice A local block is ready based on the lastest block time. This logic can be changed in future.
     @param chainId The chain ID.
     */
    function isLocalBlockReady(uint64 chainId) external view returns (bool) {
        return _isLocalBlockReady(lastLocalBlock[chainId]);
    }

    function lastRemoteMinedBlock(uint64 chainId) external view returns (QuantumPortalLib.Block memory _block) {
        _block = lastMinedBlock[chainId];
    }

    function minedBlockByNonce(uint64 chainId, uint64 blockNonce
    ) external view returns (MinedBlock memory b, QuantumPortalLib.RemoteTransaction[] memory txs) {
        uint256 key = blockIdx(chainId, blockNonce);
        b = minedBlocks[key];
        txs = minedBlockTransactions[key];
    }

    function localBlockByNonce(
        uint64 chainId,
        uint64 blockNonce
    ) external view returns (LocalBlock memory, QuantumPortalLib.RemoteTransaction[] memory) {
        uint256 key = blockIdx(chainId, blockNonce);
        return (localBlocks[key], localBlockTransactions[key]);
    }

    bytes32 constant MINE_REMOTE_BLOCK =
        keccak256("MineRemoteBlock(uint64 remoteChainId, uint64 blockNonce, bytes32 transactions, bytes32 salt)");

    /**
     @notice To mine a block we currently follow this algorithm:
        - Make sure this is right block to mine (last nonce mined, this nonce not mined)
        - Make sure the miner is allowed
        - Calculate the block hash

        Necessary improvements:
        - Allow multiple blocks to be mined (per remote chain), and honest miners to follow the valid block
        - For now, we just assume all miners are honest.
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
        uint256 lastNonce = lastMinedBlock[remoteChainId].nonce;
        // TODO: allow branching in case of conflicting blocks. When branching happens 
        // it is guaranteed that one branch is invalid and miners need to punished.
        require(blockNonce == lastNonce + 1, "QPLM: cannot jump or retrace nonce");
        bytes32 blockHash = _calculateBlockHash(
            remoteChainId,
            blockNonce,
            transactions);
        uint256 totalValue = 0;
        for (uint i=0; i < transactions.length; i++) {
            totalValue += _transactionValue(transactions[i]);
        }

        // Validate miner
        // bytes32 msgHash = keccak256(abi.encode(MINE_REMOTE_BLOCK, remoteChainId, blockNonce, transactions, salt));
        // IQuantumPortalMinerMgr.ValidationResult validationResult = IQuantumPortalMinerMgr(minerMgr).validateMinerSignature(
        //     msgHash,
        //     expiry,
        //     salt,
        //     multiSignature,
        //     totalValue,
        //     minerMinimumStake
        // );

        QuantumPortalLib.Block memory blockMetadata = QuantumPortalLib.Block({
            chainId: remoteChainId,
            nonce: blockNonce,
            timestamp: uint64(block.timestamp)
        });
        lastMinedBlock[remoteChainId] = blockMetadata;
        MinedBlock memory mb = MinedBlock({
            blockHash: blockHash,
            miner: msg.sender,
            stake: stakeOf(msg.sender),
            totalValue: totalValue,
            blockMetadata: blockMetadata
        });
        uint256 key = blockIdx(remoteChainId, blockNonce);
        minedBlocks[key] = mb;
        for(uint i=0; i<transactions.length; i++) {
            minedBlockTransactions[key].push(transactions[i]);
        }
    }

    /**
     @notice Creates an invalid block report. The raw proof is provided. 
     It would be up to the slashing mechanism to punish the malicous block producer.
     */
    function reportInvalidBlock(
        uint64 remoteChainId,
        uint64 blockNonce,
        QuantumPortalLib.RemoteTransaction[] memory transactions,
        bytes32 salt,
        uint64 expiry,
        bytes memory multiSignature
    ) external {
        // TODO: implement
    }

    /**
     @notice Finalize unfinalized blocks
     @param remoteChainId The remote chain ID. For chain that we need to finalized mined blocks
     @param blockNonce The nonce for the last block to be finalized
     */
    function finalize(
        uint256 remoteChainId,
        uint256 blockNonce,
        bytes32 finalizersHash,
        address[] memory finalizers,
        bytes32 salt,
        uint64 expiry,
        bytes memory multiSignature
    ) external {
        // bytes32 msgHash = abi.encode(FINALIZE_METHOD, remoteChainId, blockNonce, finalizersHash, salt, expiry);
        // authMgr.validateAuthoritySignature(Action.FINALIZE, msgHash, expiry, salt, multiSignature);
        // TODO: Validaate finalizers produce the right hash.
        doFinalize(remoteChainId, blockNonce, finalizersHash, finalizers);
    }

    function doFinalize(
        uint256 remoteChainId,
        uint256 blockNonce,
        bytes32 finalizersHash,
        address[] memory finalizers
    ) internal {
        QuantumPortalLib.Block memory lastFinB = lastFinalizedBlock[remoteChainId];
        QuantumPortalLib.Block memory lastMinedB = lastMinedBlock[remoteChainId];
        require(lastMinedB.chainId != 0, "QPLM: No block is mined");
        require(blockNonce <= lastMinedB.nonce, "QPLM: nonce not mined");
        require(
            lastFinB.chainId == 0 || // First time finalizing
            blockNonce > lastFinB.nonce, "QPLM: already finalized");

        bytes32 finHash = 0;
        uint256 totalBlockStake = 0;
        uint256 finalizeFrom = lastFinB.chainId == 0 ? 0 : lastFinB.nonce + 1;
        for(uint i=finalizeFrom; i <= blockNonce; i++) {
            uint256 bkey = blockIdx(uint64(remoteChainId), uint64(i));
            // uint256 stake;
            // uint256 totalValue;
            finHash = keccak256(abi.encodePacked(finHash, minedBlocks[bkey].blockHash));
            totalBlockStake += minedBlocks[bkey].stake;
            executeBlock(bkey);
        }

        FinalizationMetadata memory fin = FinalizationMetadata({
            executor: msg.sender,
            finalizedBlocksHash: finHash,
            finalizersHash: finalizersHash,
            totalBlockStake: totalBlockStake
        });
        uint256 key = blockIdx(uint64(remoteChainId), uint64(blockNonce));
        finalizations[key] = fin;

        for(uint i=0; i<finalizers.length; i++) {
            finalizationStakes[key].push(FinalizerStake({
                finalizer: finalizers[i],
                staked: stakeOf(finalizers[i])
            }));
        }

        lastFinalizedBlock[remoteChainId] = QuantumPortalLib.Block({
            chainId: uint64(remoteChainId),
            nonce: uint64(blockNonce),
            timestamp: uint64(block.timestamp)
        });

        // TODO: Produce event
    }

    /**
     @notice Returns the block idx
     */
    function getBlockIdx(uint64 chainId, uint64 nonce) external pure returns (uint256) {
        return blockIdx(chainId, nonce);
    }

    /**
     @notice Goes through every transaction and executes it. By the end charges fees for the miners and 
        cost of running
     @param key The block key
     */
    function executeBlock(
        uint256 key
    ) internal {
        MinedBlock memory b = minedBlocks[key];
        PortalLedger qp = PortalLedger(ledger);
        uint256 gasPrice = localChainGasTokenPrice();
        QuantumPortalLib.RemoteTransaction[] memory transactions = minedBlockTransactions[key]; 
        for(uint i=0; i<transactions.length; i++) {
            QuantumPortalLib.RemoteTransaction memory t = transactions[i];
            uint256 txGas = FullMath.mulDiv(gasPrice,
                t.gas, // TODO: include base fee and miner fee, etc.
                FixedPoint128.Q128);
            uint256 baseGasUsed = qp.executeRemoteTransaction(i, b.blockMetadata, t, txGas);
            console.log("REMOTE TX EXECUTED", t.gas);
            // TODO: Refund extra gas based on the ratio of gas used vs gas provided.
            // Need to convert the base gas to FRM first, and reduce the base fee.
        }
        qp.clearContext();
    }

    /**
     @notice Save gas by packing a multidic key into one key
     */
    function blockIdx(uint64 chainId, uint64 nonce) private pure returns (uint256) {
        return (uint256(chainId) << 64) + nonce;
    }

    /**
     @notice Returns the token price vs FRM (fixed point 128). TODO: Implement
     @param token The token
     @return The price
     */
    function tokenPriceX128(
        address token
    ) internal virtual view returns (uint256) {
        return 0;
    }

    /**
     @notice Ruetnrs the FRM price for the current chain native gas (e.g. ETH)
     @return The price
     */
    function localChainGasTokenPrice(
    ) internal virtual view returns (uint256) {
        return 1;
    }

    /**
     @notice Returns available stake of the staker. TODO: Implement
     @param staker The staker address
     @return The available staked amount
     */
    function stakeOf(
        address staker
    ) internal virtual returns (uint256) {
        return 0;
    }

    /**
     @notice Identifies if we are ready for a new block
     */
    function _isLocalBlockReady(QuantumPortalLib.Block memory b) private view returns (bool) {
        return (block.timestamp - b.timestamp) >= BLOCK_PERIOD;
    }

    /**
     @notice Returns a unique block hash.
     */
    function  _calculateBlockHash(
        uint64 remoteChainId,
        uint64 blockNonce,
        QuantumPortalLib.RemoteTransaction[] memory transactions
    ) private pure returns (bytes32) {
        return keccak256(abi.encode(
            remoteChainId,
            blockNonce,
            transactions
            ));
    }

    function _transactionValue(
        QuantumPortalLib.RemoteTransaction memory transaction
    ) private view returns (uint256 value) {
        value += FullMath.mulDiv(tokenPriceX128(transaction.token), transaction.amount, FixedPoint128.Q128);
    }
}

contract QuantumPortalLedgerMgrImpl is QuantumPortalLedgerMgr {
    constructor() QuantumPortalLedgerMgr(0) { }
}