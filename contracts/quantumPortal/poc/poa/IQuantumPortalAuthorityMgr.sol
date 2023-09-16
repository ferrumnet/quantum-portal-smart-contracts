// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IQuantumPortalAuthorityMgr {
    enum Action {
        NONE,
        FINALIZE,
        SLASH
    }

    function validateAuthoritySignature(
        Action action,
        bytes32 msgHash,
        bytes32 salt,
        uint64 expiry,
        bytes memory signature
    ) external;

    function validateAuthoritySignatureSingleSigner(
        Action action,
        bytes32 msgHash,
        bytes32 salt,
        uint64 expiry,
        bytes memory signature
    ) external returns (address[] memory signers, bool quorumComplete);
}
