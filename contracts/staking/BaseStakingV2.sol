// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IStakeV2.sol";
import "./interfaces/IStakeInfo.sol";
import "./library/StakingBasics.sol";
import "./library/Admined.sol";
import "./vesting/VestingLibrary.sol";
import "./library/TokenReceivable.sol";
import "./library/StakingV2CommonSignatures.sol";
import "./factory/IStakingFactory.sol";
import "foundry-contracts/contracts/common/IFerrumDeployer.sol";
import "foundry-contracts/contracts/taxing/IGeneralTaxDistributor.sol";

abstract contract BaseStakingV2 is IStakeV2, IStakeInfo, TokenReceivable, Admined,
  StakingV2CommonSignatures {
  using StakeFlags for uint16;
  address public /*immutable*/ factory;
  StakingBasics.StakeExtraInfo internal extraInfo;
  StakingBasics.StakeBaseInfo internal baseInfo;
  StakingBasics.StakeState internal state;
  StakingBasics.RewardState internal reward;
  VestingLibrary.VestingSchedule internal vesting;
  mapping(address => StakingBasics.StakeInfo) public stakings;
  event RewardPaid(address id, address staker, address to, address[] rewardTokens, uint256[] rewards);
  event BasePaid(address id, address staker, address to, address token, uint256 amountPaid);
  event Staked(address id, address tokenAddress, address staker, uint256 amount);
  event RewardAdded(address id, address rewardToken, uint256 rewardAmount);
  address public creationSigner;
  constructor() {
    bytes memory _data = IFerrumDeployer(msg.sender).initData();
    (factory) = abi.decode(_data, (address));
  }

  function setCreationSigner(address _signer) external onlyOwner {
    creationSigner = _signer;
  }

	// TODO: Make this a gov multisig request
	function setLockSeconds(address id, uint256 _lockSeconds) external onlyOwner {
		require(id != address(0), "BSV: id required");
    StakingBasics.StakeInfo memory stake = stakings[id];
    require(stake.stakeType != Staking.StakeType.None, "BSV2: Not initialized");
		extraInfo.lockSeconds[id] = uint64(_lockSeconds);
	}

	function rewardsTotal(address id, address rewardAddress) external view returns (uint256) {
		return reward.rewardsTotal[id][rewardAddress];
	}

	function lockSeconds(address id) external view returns (uint256) {
		return extraInfo.lockSeconds[id];
	}

  function setAllowedRewardTokens(address id, address[] memory tokens) internal {
    extraInfo.allowedRewardTokenList[id] = tokens;
    for(uint i=0; i < tokens.length; i++) {
      extraInfo.allowedRewardTokens[id][tokens[i]] = true;
    }
  }

  function ensureWithdrawAllowed(StakingBasics.StakeInfo memory stake) internal pure {
    require(
      !stake.flags.checkFlag(StakeFlags.Flag.IsRecordKeepingOnly) &&
      !stake.flags.checkFlag(StakeFlags.Flag.IsBaseSweepable), "BSV2: Record keeping only");
    require(stake.stakeType != Staking.StakeType.PublicSale, "BSV2: No withdraw on public sale");
  }

	function stakedBalance(address id) external override view returns (uint256) {
		return state.stakedBalance[id];
	}

	function stakeOf(address id, address staker) external override view returns (uint256) {
		return state.stakes[id][staker];
	}

	function fakeRewardOf(address id, address staker, address rewardToken)
	external view returns (uint256) {
		return reward.fakeRewards[id][staker][rewardToken];
	}

	function fakeRewardsTotal(address id, address rewardToken)
	external view returns (uint256) {
		return reward.fakeRewardsTotal[id][rewardToken];
	}

	function allowedRewardTokens(address id, address rewardToken) external view returns (bool) {
		return extraInfo.allowedRewardTokens[id][rewardToken];
	}

	function allowedRewardTokenList(address id) external view returns (address[] memory) {
		return extraInfo.allowedRewardTokenList[id];
	}

  function sweepBase(address id) external {
    StakingBasics.StakeInfo memory stake = stakings[id];
    require(stake.stakeType != Staking.StakeType.None, "BSV2: Not initialized");
    require(stake.flags.checkFlag(StakeFlags.Flag.IsBaseSweepable), "BSV2: Base not sweepable");
    address sweepTarget = extraInfo.sweepTargets[id];
    require(sweepTarget != address(0), "BSV2: No sweep target");
    uint256 currentSwept = state.stakeSwept[id];
    uint256 balance = state.stakedBalance[id];
    state.stakeSwept[id] = balance;
    sendToken(baseInfo.baseToken[id], sweepTarget, balance-(currentSwept));
  }

  function sweepRewards(address id, address[] memory rewardTokens) external {
    StakingBasics.StakeInfo memory stake = stakings[id];
    require(stake.stakeType != Staking.StakeType.None, "BSV2: Not initialized");
    require(stake.flags.checkFlag(StakeFlags.Flag.IsRewardSweepable), "BSV2: Reward not sweepable");
    require(block.timestamp > stake.endOfLife, "BSV2: Only after end of life");
    address sweepTarget = extraInfo.sweepTargets[id];
    require(sweepTarget != address(0), "BSV2: No sweep target");
    for(uint i=0; i<rewardTokens.length; i++) {
      _sweepSignleReward(id, rewardTokens[i], sweepTarget);
    }
  }

  function _sweepSignleReward(address id, address rewardToken, address sweepTarget) internal {
    uint256 totalRewards = reward.rewardsTotal[id][rewardToken];
    uint256 toPay = totalRewards-(reward.fakeRewardsTotal[id][rewardToken]);
    reward.fakeRewardsTotal[id][rewardToken] = totalRewards;
    sendToken(rewardToken, sweepTarget, toPay);
  }
	
  function baseToken(address id) external override view returns (address) {
    return baseInfo.baseToken[id];
  }

  function isTokenizable(address id) external override view returns(bool) {
    return stakings[id].flags.checkFlag(StakeFlags.Flag.IsTokenizable);
  }

  function name(address id) external override view returns (string memory _name) {
    _name = baseInfo.name[id];
  }

  modifier nonZeroAddress(address addr) {
    require(addr != address(0), "BaseStakingV2: zero address");
    _;
  }

  modifier onlyAdmin(address id) {
    require(admins[id][msg.sender] != StakingBasics.AdminRole.None, "BSV2: You are not admin");
    _;
  }
}