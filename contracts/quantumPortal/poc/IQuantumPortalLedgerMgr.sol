
interface IQuantumPortalLedgerMgr {
    function registerTransaction(
        uint64 remoteChainId,
        address remoteContract,
        address msgSender,
        address beneficiary,
        address token,
        uint256 amount,
        uint256 gas,
        bytes memory method
    ) external;
}