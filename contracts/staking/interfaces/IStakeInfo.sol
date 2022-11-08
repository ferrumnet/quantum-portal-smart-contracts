// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStakeInfo {
    function stakedBalance(address id) external view returns (uint256);
    function stakeOf(address id, address staker) view external returns (uint256);
    function isTokenizable(address id) external view returns (bool);
}

interface IStakeTransferrer {
	function transferFromOnlyPool(address stakingPoolId,
			address sender, address from, address to, uint256 value
		) external returns (bool);
	function approveOnlyPool(address id, address sender, address spender, uint value
		) external returns (bool);
  function transferOnlyPool(address id, address from, address to, uint256 amount
		) external;
	function allowance(address id, address owner, address spender
	  ) external view returns (uint256);
}