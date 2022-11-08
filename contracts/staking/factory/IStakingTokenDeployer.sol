// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStakingTokenDeployer {
    function parameters() external returns (address, address, address, string memory, string memory);
}