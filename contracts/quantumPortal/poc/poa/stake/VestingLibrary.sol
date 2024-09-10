// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./library/StakingBasics.sol";
import "foundry-contracts/contracts/contracts/math/FullMath.sol";
import "foundry-contracts/contracts/contracts/math/SafeCast.sol";
import "foundry-contracts/contracts/contracts/math/FixedPoint128.sol";

library VestingLibrary {
  function calculatePoolShare(uint256 shareBalance, uint256 stakeBalance)
  internal pure returns (uint256 poolShareX128) {
      require(stakeBalance != 0, "VL: Balance zero");
      poolShareX128 = FullMath.mulDiv(shareBalance, FixedPoint128.Q128, stakeBalance);
  }

  function calculateFakeRewardForWithdraw(uint256 rewardAmount, uint256 remainingStakeRatioX128)
  internal pure returns (uint256) {
    return FullMath.mulDiv(rewardAmount, remainingStakeRatioX128, FixedPoint128.Q128);
  }
}
