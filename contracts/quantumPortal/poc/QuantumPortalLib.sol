// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @notice Helper library for QP contracts
 */
library QuantumPortalLib {
    address constant FRAUD_PROOF = 0x00000000000000000000000000000000000f4a0D;

    enum MethodsEventIndex {
        CallMethod,
        OnError,
        OnComplete
    }

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

    /**
     * @notice Compares equality of two transactions
     * @param t1 First transaction
     * @param t2 Second transaction
     */
    function txEquals(
        RemoteTransaction memory t1,
        RemoteTransaction memory t2
    ) internal pure returns (bool) {
        bool methodsMatch = t1.methods.length == t2.methods.length;
        if (methodsMatch && t1.methods.length != 0) {
            for (uint i=0; i < t1.methods.length; i++) {
                methodsMatch = methodsMatch && (keccak256(t1.methods[i]) == keccak256(t2.methods[i]));
                if (!methodsMatch) {
                    return false;
                }
            }
        } else {
            return false;
        }
        return
            t1.timestamp == t2.timestamp &&
            t1.remoteContract == t2.remoteContract &&
            t1.sourceMsgSender == t2.sourceMsgSender &&
            t1.sourceBeneficiary == t2.sourceBeneficiary &&
            t1.token == t2.token &&
            t1.amount == t2.amount &&
            methodsMatch &&
            t1.methods.length == t2.methods.length &&
            t1.gas == t2.gas &&
            t1.fixedFee == t2.fixedFee;
    }
}
