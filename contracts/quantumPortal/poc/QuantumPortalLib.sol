// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @notice Helper library for QP contracts
 */
library QuantumPortalLib {
    struct RemoteBalance {
        uint64 remoteChainId;
        address remoteAddress;
        address remoteToken;
        uint256 remoteBalance;
    }

    struct Block {
        uint64 chainId;
        uint64 nonce;
        uint64 timestamp;
    }

    struct RemoteTransaction {
        uint64 timestamp;
        address remoteContract;
        address sourceMsgSender;
        address sourceBeneficiary; // This can be set by the contract. Revert refunds will be made to this
        address token;
        uint256 amount;
        bytes[] methods; // Different methods and events packed here
        uint256 gas; // Provided gas in FRM, to run the transaction
        uint256 fixedFee; // To pay miners and finalizers
    }

    struct Context {
        uint64 index;
        Block blockMetadata;
        RemoteTransaction transaction;
        uint256 uncommitedBalance; // Balance for transaction.token
    }

    enum MethodsEventIndex {
        CallMethod,
        OnError,
        OnComplete
    }

    address constant FRAUD_PROOF = 0x00000000000000000000000000000000000f4a0D;

    /**
     * @notice Compares equality of two transactions
     * @param t1 First transaction
     * @param t2 Second transaction
     */
    function txEquals(
        RemoteTransaction memory t1,
        RemoteTransaction memory t2
    ) internal pure returns (bool) {
        if (t1.timestamp != t2.timestamp ||
            t1.remoteContract != t2.remoteContract) { // Short circuit for most common case
            return false; 
        }

        return keccak256(abi.encode(t1)) == keccak256(abi.encode(t2));
    }
}
