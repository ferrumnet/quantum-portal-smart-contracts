// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

interface IQuantumPortalLedgerMgrDependencies {
    function minerMgr() external view returns (address);
    function authorityMgr() external view returns (address);
}