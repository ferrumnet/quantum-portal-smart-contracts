
interface IQuantumPortalAuthorityMgr {
    enum Action { NONE, FINALIZE, SLASH }
    function validateAuthoritySignature(
        Action action,
        bytes32 msgHash,
        bytes32 salt,
        uint64 expiry,
        bytes memory signature
    ) external;
}
