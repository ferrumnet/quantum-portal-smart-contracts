// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./QuantumPortalLib.sol";

interface IQuantumPortalLedgerMgr {
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

    function registerTransaction(
        uint64 remoteChainId,
        address remoteContract,
        address msgSender,
        address beneficiary,
        address token,
        uint256 amount,
        bytes memory method
    ) external;
}

interface IQuantumPortalLedgerMgrDependencies {
    function minerMgr() external view returns (address);
    function authorityMgr() external view returns (address);
}