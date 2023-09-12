// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./QuantumPortalLib.sol";
import "./QuantumPortalState.sol";

interface IQuantumPortalLedgerMgr {
    struct LocalBlock {
        QuantumPortalLib.Block metadata;
    }
    struct MinedBlock {
        bytes32 blockHash;
        address miner;
        uint8 invalidBlock;
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

    function submitFraudProof(
        uint64 minedOnChainId,
        uint64 localBlockNonce,
        uint64 localBlockTimestamp,
        QuantumPortalLib.RemoteTransaction[] memory transactions,
        bytes32 salt,
        uint64 expiry,
        bytes memory multiSignature,
        address rewardReceiver
    ) external;

    function state() external returns (QuantumPortalState);
}

interface IQuantumPortalLedgerMgrDependencies {
    function minerMgr() external view returns (address);
    function authorityMgr() external view returns (address);
}