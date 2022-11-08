// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../BaseStakingV2.sol";
import "../factory/IStakingFactory.sol";

abstract contract TokenizableStaking is BaseStakingV2, IStakeTransferrer {
  using SafeMath for uint256;
  mapping(address => mapping(address => mapping(address => uint))) public override allowance;

	function _approve(address id, address owner, address spender, uint value) private {
			allowance[id][owner][spender] = value;
	}

  function _transfer(
    address id,
    address from,
    address to,
    uint256 amount)
	internal virtual {
		/*
		 To transfer an stake, we need to transfer 3 things:
		 1. The stake
		 2. The debt
		 3. The fake rewards?
		 The rewards part is going to be tricky. Because it can change fungability!!!
		 Need a proper solution here.
		 - 
		*/

		uint256 stakeFrom = state.stakes[id][from];
		uint256 debtFrom = state.stakeDebts[id][from];

		state.stakes[id][from] = stakeFrom.sub(amount);
		uint256 stakeTo = state.stakes[id][to];
		state.stakes[id][to] = stakeTo.add(amount);

		uint256 debtTo = state.stakeDebts[id][to];
		uint256 debtAmount = FullMath.mulDiv(amount, debtFrom, stakeFrom);
		debtFrom = debtFrom.sub(debtAmount);
		debtTo = debtTo.add(debtAmount);
		state.stakeDebts[id][to] = debtTo;
		state.stakeDebts[id][from] = debtFrom;
  }

  /**
   * move part of the lgic here to the pool to reduce state read volume and save gas
   */
  function transferOnlyPool(address id, address from, address to, uint256 amount)
  external override onlyPool(id) nonZeroAddress(id) nonZeroAddress(from) nonZeroAddress(to) {
    require(amount != 0, "BSV2: amount is requried");
		_transfer(id, from, to, amount);
  }

	function approveOnlyPool(address id, address sender, address spender, uint value)
	external override onlyPool(id) returns (bool) {
			_approve(id, sender, spender, value);
			return true;
	}
	
	function transferFromOnlyPool(address id, address sender, address from, address to, uint value)
	external override onlyPool(id) returns (bool) {
			if (allowance[id][from][sender] != type(uint256).max) {
					allowance[id][from][sender] = allowance[id][from][sender].sub(value);
			}
			_transfer(id, from, to, value);
			return true;
	}

  modifier onlyPool(address id) {
    require(IStakingFactory(factory)
			.getPool(address(this), id) == msg.sender, "STP: caller not allowed");
    _;
  }
}
