// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @notice An authority manager
 */
interface IQuantumPortalAuthorityMgr {
    enum Action {
        NONE,
        FINALIZE,
        SLASH,
        ALLOW_ACTION
    }

    /**
     * @notice Validates the authority signature
     * @param action The action
     * @param msgHash The message hash (summary of the object to be validated)
     * @param salt A unique salt
     * @param expiry Signature expiry
     * @param signature The signatrue
     */
    function validateAuthoritySignature(
        Action action,
        bytes32 msgHash,
        bytes32 salt,
        uint64 expiry,
        bytes memory signature
    ) external returns (address[] memory validators);
}
