// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../../../common/signature/MultiSigCheckable.sol";

interface IQuantumPortalAuthorityMgr {
    enum Action { NONE, FINALIZE, SLASH }
    function validateAuthoritySignature(
        Action action,
        bytes32 msgHash,
        uint64 expiry,
        bytes32 salt,
        bytes memory signature
    ) external;
}

/**
 @notice Authority manager, provides authority signature verification, for 
    different actions.
 */
contract QuantumPortalAuthorityMgr is IQuantumPortalAuthorityMgr, MultiSigCheckable {
    string public constant NAME = "FERRUM_QUANTUM_PORTAL_AUTHORITY_MGR";
    string public constant VERSION = "000.010";

    constructor() EIP712(NAME, VERSION) {}

    bytes32 constant VALIDATE_AUTHORITY_SIGNATURE =
        keccak256("ValidateAuthoritySignature(uint256 action,bytes32 msgHash,bytes32 salt)");

    /**
     @notice Validates an authority signature
             TODO: Update to differentiate between finalize and slash. For example more
             signers requred for slash
     */
    function validateAuthoritySignature(
        Action action,
        bytes32 msgHash,
        uint64 expiry,
        bytes32 salt,
        bytes memory signature
    ) external override {
        require(action != Action.NONE, "QPAM: action required");
        require(msgHash != bytes32(0), "QPAM: msgHash required");
        require(expiry != 0, "QPAM: expiry required");
        require(salt != 0, "QPAM: salt required");
        require(expiry > block.timestamp, "QPAM: signature expired");
        bytes32 message = keccak256(abi.encode(VALIDATE_AUTHORITY_SIGNATURE, uint256(action), msgHash, salt));
        verifyUniqueSalt(message, salt, 1, signature);
    }
}