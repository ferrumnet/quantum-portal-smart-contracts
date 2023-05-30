// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IQuantumPortalWorkPoolServer {
    function collectFee(uint256 targetChainId, uint256 localEpoch, uint256 fixedFee) external returns (uint256 varFee);
    function withdrawFixedRemote(address worker, uint256 workRatioX128, uint256 epoch) external;
    function withdrawVariableRemote(address worker, uint256 workRatioX128, uint256 epoch) external;
}