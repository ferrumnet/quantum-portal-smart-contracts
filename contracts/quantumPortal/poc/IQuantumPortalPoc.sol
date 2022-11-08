// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./QuantumPortalLib.sol";

interface IQuantumPortalPoc {
    function feeManager() external view returns(address);
    function run(uint256 fee, uint64 remoteChain, address remoteContract, address beneficiary, bytes memory remoteMethodCall) external;
    function runWithValue(
        uint256 fee, uint64 remoteChain, address remoteContract, address beneficiary, address token, bytes memory method) external;
    function runWithdraw(
        uint256 fee, uint64 remoteChainId, address remoteAddress, address token, uint256 amount) external;

    function msgSender() external view returns (uint256 sourceNetwork, address sourceMsgSender, address sourceBeneficiary);
    function txContext() external view returns (QuantumPortalLib.Context memory);
    function remoteTransfer(uint256 chainId, address token, address to, uint256 amount) external;
}