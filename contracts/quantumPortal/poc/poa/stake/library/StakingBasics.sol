// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../interfaces/IStakeV2.sol";

library StakeFlags {
  enum Flag { RestrictRewards, IsBaseSweepable, IsRewardSweepable, IsTokenizable, IsFeeable,
    IsCustomFeeable, IsAllocatable, IsRecordKeepingOnly, IsMandatoryLocked }

  function checkFlag(uint16 dis, Flag f) internal pure returns (bool) {
    return dis & (1 >> uint16(f)) != 0;
  }

  function withFlag(uint16 dis, Flag f, bool value) internal pure returns (uint16 res) {
    if (value) {
      res = dis | uint16(1 << uint16(f));
    } else {
      res= dis & (uint16(1 << uint16(f)) ^ uint16(0));
    }
  }
}

library StakingBasics {
  enum AdminRole { None, StakeAdmin, StakeCreator }
  struct RewardState {
    mapping(address => mapping(address => uint256)) rewardsTotal;
    // Fake rewards acts differently for open ended vs timed staking.
    // For open ended, fake rewards is used to balance the rewards ratios going forward
    // for timed, fakeRewards reflect the amount of rewards paid to the user.
    mapping(address => mapping(address => uint256)) fakeRewardsTotal;
    mapping(address => mapping(address => mapping(address => uint256))) fakeRewards;
  }

  struct StakeBaseInfo {
    mapping(address => uint256) cap;
    mapping(address => address) baseToken;
    mapping(address => string) name;
  }

  struct StakeInfo {
    Staking.StakeType stakeType;
    bool restrictedRewards; // Packing redundant configs as booleans for gas saving
    uint32 contribStart;
    uint32 contribEnd;
    uint32 endOfLife; // No more reward paid after this time. Any reward left can be swept
    uint32 configHardCutOff;
    uint16 flags;
  }

  struct StakeExtraInfo {
    mapping(address => mapping(address => bool)) allowedRewardTokens;
    mapping(address => address[]) allowedRewardTokenList;
    mapping(address => address) allocators;
    mapping(address => address) feeTargets;
    mapping(address => address) sweepTargets;
    mapping(address => uint64) lockSeconds;
  }

  struct StakeState {
    mapping(address => uint256) stakedBalance;
    mapping(address => uint256) stakedTotal;
    mapping(address => uint256) stakeSwept;
    mapping(address => mapping(address => uint256)) stakes;
    mapping(address => mapping(address => uint256)) stakeDebts;
  }
}
