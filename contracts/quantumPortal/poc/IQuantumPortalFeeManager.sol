// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IQuantumPortalFeeManager {
    function feeToken() external view returns (address);

    function depositFee(address contractAddress) external;
}
