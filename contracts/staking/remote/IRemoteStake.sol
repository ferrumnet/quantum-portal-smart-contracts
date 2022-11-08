// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRemoteStake {
	function syncStake(address to, address token) external;
    function withdrawRewardsFor(address to, address baseToken) external returns (uint256);
	function addReward(address token, address rewardToken) external returns(uint256);
}