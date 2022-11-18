// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../library/StakingBasics.sol";
import "foundary-contracts/contracts/math/FullMath.sol";
import "foundary-contracts/contracts/math/SafeCast.sol";
import "foundary-contracts/contracts/math/FixedPoint128.sol";

library VestingLibrary {
  using SafeMath for uint256;
  uint256 constant YEAR_IN_SECONDS = 365 * 24 * 3600;
  enum PeriodType { Unlocked, NoWithdraw, LinearReward, LinearBase, LinearBaseLinearReward }
  struct VestingItem {
    uint160 amount;
    uint32 endTime;
    PeriodType periodType;
  }

  struct VestingSchedule {
    mapping(address => mapping(address => uint256)) maxApyX10000; // (display only) Max APY * 10000 (20% => 2,000). For display only
    mapping(address => mapping(address => uint256)) maxApyX128; // Max APY considering price of base / reward
    mapping(address => mapping(address => uint256)) rewardAdded; // Total amount of added rewards
    mapping(address => mapping(address => uint256)) rewardPaid; // Total amount of paid
    mapping(address => mapping(address => VestingItem[])) items;
  }

  function getPegPriceX128(address id,
    address rewardToken,
    mapping(address => mapping(address => uint256)) storage maxApyX10000,
    mapping(address => mapping(address => uint256)) storage maxApyX128)
    internal view returns (uint256 _maxApyX10000, uint256 baseRewRatioX128) {
    _maxApyX10000 = maxApyX10000[id][rewardToken];
    uint256 _maxApyX128 = maxApyX128[id][rewardToken];
    baseRewRatioX128 = FullMath.mulDiv(_maxApyX128, _maxApyX10000, 10000);
  }

  function setVestingSchedule(
    address id,
    address rewardToken,
    uint256 maxApyX10000,
    uint256 baseRewRatioX128, // Price of base over rew. E.g. rew FRMX, base FRM => $0.5*10^6/(10,000*10^18)
    uint32[] calldata endTimes,
    uint128[] calldata amounts,
    PeriodType[] calldata periodTypes,
    VestingSchedule storage vesting) internal {
    // Set the maxApy
    if (maxApyX10000 != 0) {
      uint256 _maxApyX128 = FullMath.mulDiv(maxApyX10000, baseRewRatioX128, 10000);
      vesting.maxApyX128[id][rewardToken] = _maxApyX128;
    }
    vesting.maxApyX10000[id][rewardToken] = maxApyX10000;

    for(uint i=0; i < endTimes.length; i++) {
      require(endTimes[i] != 0, "VestingLibrary: startTime required");
      if (periodTypes[i] == PeriodType.LinearBase || periodTypes[i] == PeriodType.LinearBaseLinearReward) {
        require(i == endTimes.length - 1, "VestingLibrary: linearBase only applies to the last period");
      }
      VestingItem memory vi = VestingItem({
        amount: SafeCast.toUint160(amounts[i]),
        endTime: endTimes[i],
        periodType: periodTypes[i]
        });
      vesting.items[id][rewardToken][i] = vi;
    }
  } 

  function rewardRequired(address id,
    address rewardToken,
    mapping(address => mapping(address => VestingItem[])) storage items,
    mapping(address => mapping(address => uint256)) storage rewardAdded) external view returns (uint256) {
    uint256 total = 0;
    uint256 len = items[id][rewardToken].length;
    require(len != 0 ,"VL: No vesting defined");
    for(uint i=0; i < len; i++) {
      uint256 vAmount = items[id][rewardToken][i].amount;
      total = total.add(vAmount);
    }
    return total.sub(rewardAdded[id][rewardToken]);
  }

  function calculatePoolShare(uint256 shareBalance, uint256 stakeBalance)
  internal pure returns (uint256 poolShareX128) {
      require(stakeBalance != 0, "VL: Balance zero");
      poolShareX128 = FullMath.mulDiv(shareBalance, FixedPoint128.Q128, stakeBalance);
  }

  function calculateMaxApy(uint256 baseTime, uint256 timeNow,
      uint256 maxApyX128, uint256 amount) internal pure returns (uint256) {
          require(timeNow > baseTime, "VL: Bad timing");
          return FullMath.mulDiv(amount, maxApyX128.mul(timeNow - baseTime),
            FixedPoint128.Q128.mul(YEAR_IN_SECONDS));
  }

  function calculateFeeX10000(uint256 amount, uint256 feeX10000) internal pure returns (uint256) {
    return FullMath.mulDiv(amount, feeX10000, 10000);
  }

  function calculateRatio(uint256 amount, uint256 feeX10000) internal pure returns (uint256) {
    return FullMath.mulDiv(amount, feeX10000, 10000);
  }

  function calculateFakeRewardForWithdraw(uint256 rewardAmount, uint256 remainingStakeRatioX128)
  internal pure returns (uint256) {
    return FullMath.mulDiv(rewardAmount, remainingStakeRatioX128, FixedPoint128.Q128);
  }

  function calculateRemainingStakeRatioX128(uint256 userBalance, uint256 withdrawAmount)
  internal pure returns (uint256) {
    return FullMath.mulDiv(userBalance.sub(withdrawAmount), FixedPoint128.Q128, userBalance);
  }

  function calculateVestedRewards(
      uint256 poolShareX128,
      uint256 stakingEnd,
      uint256 timeNow,
      uint256 maxApyRew,
      uint256 totalRewards,
      VestingItem[] memory items
      ) internal pure returns (uint256 reward, bool linearBase) {
      /*
        Stretch until the appropriate time, calculate piecewise rewards.
      */
      uint256 i=0;
      VestingItem memory item = items[0];
      uint256 lastTime = stakingEnd;
      while (item.endTime <= timeNow && i < items.length) {
        reward = reward.add(FullMath.mulDiv(poolShareX128, totalRewards, FixedPoint128.Q128));
        i++;
        if (i < items.length) {
          item = items[i];
        }
      }

      uint256 endTime = item.endTime; // To avoid too many type conversions
      // Partial take
      if (endTime > timeNow &&
        (item.periodType == PeriodType.LinearReward || item.periodType == PeriodType.LinearBaseLinearReward)) {
          reward = reward.add(FullMath.mulDiv(poolShareX128, totalRewards, FixedPoint128.Q128));
          uint256 letGoReward = FullMath.mulDiv(reward, timeNow.sub(endTime), lastTime.sub(endTime));
          reward = reward.sub(letGoReward);
          if (item.periodType == PeriodType.LinearBaseLinearReward) { linearBase = true; }
      }
      if (maxApyRew != 0 && reward != 0 && reward > maxApyRew) {
          // Dont give out more than the max_apy
          // maxApyRew to be calculated as calculateMaxApy()
          reward = maxApyRew;
      }
    }
}
