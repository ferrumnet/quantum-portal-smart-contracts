// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface ISlashableStake {
    function slash(address id, address staker, uint256 amount) external;
}
