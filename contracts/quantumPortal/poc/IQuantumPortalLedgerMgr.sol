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

    struct FinalizerStake {
        address finalizer;
        uint256 staked;
    }

    struct FinalizationMetadata {
        address executor;
        bytes32 finalizedBlocksHash;
        bytes32 finalizationHash;
        uint256 totalBlockStake;
    }

    /**
     * @notice The state contract
     */
    function state() external returns (QuantumPortalState);

    /**
     * notice Register a multi-chain transaction
     * @param remoteChainId The remote chain ID
     * @param remoteContract The remove contract address
     * @param msgSender Message sender address. This will be the address of initiating contract
     * @param beneficiary Beneficiary. This is the address that recieves the funds / refunds in
     *   in case the transaction rejected or failed
     * @param token The token to send to the remote contract
     * @param amount The amount to send the remote contract
     * @param method The encoded method to call
     */
    function registerTransaction(
        uint64 remoteChainId,
        address remoteContract,
        address msgSender,
        address beneficiary,
        address token,
        uint256 amount,
        bytes memory method
    ) external;

    /**
     * @notice Submit a fraud proof transaction
     * @param minedOnChainId The chain ID of fragulent block
     * @param localBlockNonce The nonce of the fragulent block
     * @param localBlockTimestamp The timestamp on the local block
     * @param transactions Transactions in the block
     * @param salt Salt used by the miner
     * @param expiry Expiry used by the miner
     * @param multiSignature The multi siganure containing miner's signature
     * @param rewardReceiver The reward received address
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
    ) external;
}

interface IQuantumPortalLedgerMgrDependencies {

    /**
     * @notice The miner manager
     */
    function minerMgr() external view returns (address);

    /**
     * @notice The authority manager
     */
    function authorityMgr() external view returns (address);
}
