// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IGeneralTaxDistributor} from "foundry-contracts/contracts/contracts/taxing/IGeneralTaxDistributor.sol";
import {WithAdminUpgradeable} from "foundry-contracts/contracts/contracts-upgradeable/common/WithAdminUpgradeable.sol";
import {Staking, IStakeV2} from "./interfaces/IStakeV2.sol";
import {IStakeInfo} from "./interfaces/IStakeInfo.sol";
import {StakingBasics, StakeFlags} from "./library/StakingBasics.sol";
import {TokenReceivableUpgradeable} from "./library/TokenReceivableUpgradeable.sol";
import {StakingV2CommonSignaturesUpgradeable} from "./library/StakingV2CommonSignaturesUpgradeable.sol";
import {IStakingFactory} from "./factory/IStakingFactory.sol";


abstract contract BaseStakingV2Upgradeable is 
	Initializable,
	IStakeV2,
	IStakeInfo,
	TokenReceivableUpgradeable,
	WithAdminUpgradeable
{
	using StakeFlags for uint16;
	/// @custom:storage-location erc7201:ferrum.storage.basestakingv2.001
	struct BaseStakingV2StorageV001 {
		address creationSigner;
		StakingBasics.StakeExtraInfo extraInfo;
		StakingBasics.StakeBaseInfo baseInfo;
		StakingBasics.StakeState state;
		StakingBasics.RewardState reward;
		mapping(address => StakingBasics.StakeInfo) stakings;
	}

	// keccak256(abi.encode(uint256(keccak256("ferrum.storage.basestakingv2.001")) - 1)) & ~bytes32(uint256(0xff))
	bytes32 private constant BaseStakingV2StorageV001Location = 0x4f9e11f8f9590b50e76bc2b26792e2af134c9aa9d6c8cd607c56da3662f40200;

	event RewardPaid(address id, address staker, address to, address[] rewardTokens, uint256[] rewards);
	event BasePaid(address id, address staker, address to, address token, uint256 amountPaid);
	event Staked(address id, address tokenAddress, address staker, uint256 amount);
	event RewardAdded(address id, address rewardToken, uint256 rewardAmount);

	modifier nonZeroAddress(address addr) {
		require(addr != address(0), "BaseStakingV2: zero address");
		_;
	}

	function __BaseStakingV2_init() internal onlyInitializing {
		// __EIP712Upgradeable_init(); // This 2 need to be called from child contract!
		__TokenReceivable_init();
	}

	function creationSigner() public view returns (address) {
		return _getBaseStakingV2StorageV001().creationSigner;
	}

	function stakings(address id) public view returns (StakingBasics.StakeInfo memory) {
		return _getBaseStakingV2StorageV001().stakings[id];
	}

	function setCreationSigner(address _signer) external onlyAdmin {
		_getBaseStakingV2StorageV001().creationSigner = _signer;
	}

	// TODO: Make this a gov multisig request
	function setLockSeconds(address id, uint256 _lockSeconds) external onlyAdmin {
		require(id != address(0), "BSV: id required");
		BaseStakingV2StorageV001 storage $ = _getBaseStakingV2StorageV001();
		StakingBasics.StakeInfo memory stake = stakings(id);
		require(stake.stakeType != Staking.StakeType.None, "BSV2: Not initialized");
		$.extraInfo.lockSeconds[id] = uint64(_lockSeconds);
	}

	function rewardsTotal(address id, address rewardAddress) external view returns (uint256) {
		BaseStakingV2StorageV001 storage $ = _getBaseStakingV2StorageV001();
		return $.reward.rewardsTotal[id][rewardAddress];
	}

	function lockSeconds(address id) external view returns (uint256) {
		BaseStakingV2StorageV001 storage $ = _getBaseStakingV2StorageV001();
		return $.extraInfo.lockSeconds[id];
	}

	function setAllowedRewardTokens(address id, address[] memory tokens) internal {
		BaseStakingV2StorageV001 storage $ = _getBaseStakingV2StorageV001();
		$.extraInfo.allowedRewardTokenList[id] = tokens;
		for(uint i=0; i < tokens.length; i++) {
		$.extraInfo.allowedRewardTokens[id][tokens[i]] = true;
		}
	}

	function ensureWithdrawAllowed(StakingBasics.StakeInfo memory stake) internal pure {
		require(
		!stake.flags.checkFlag(StakeFlags.Flag.IsRecordKeepingOnly) &&
		!stake.flags.checkFlag(StakeFlags.Flag.IsBaseSweepable), "BSV2: Record keeping only");
		require(stake.stakeType != Staking.StakeType.PublicSale, "BSV2: No withdraw on public sale");
	}

	function stakedBalance(address id) external override view returns (uint256) {
		BaseStakingV2StorageV001 storage $ = _getBaseStakingV2StorageV001();
		return $.state.stakedBalance[id];
	}

	function stakeOf(address id, address staker) external override view returns (uint256) {
		BaseStakingV2StorageV001 storage $ = _getBaseStakingV2StorageV001();
		return $.state.stakes[id][staker];
	}

	function fakeRewardOf(address id, address staker, address rewardToken)
	external view returns (uint256) {
		BaseStakingV2StorageV001 storage $ = _getBaseStakingV2StorageV001();
		return $.reward.fakeRewards[id][staker][rewardToken];
	}

	function fakeRewardsTotal(address id, address rewardToken)
	external view returns (uint256) {
		BaseStakingV2StorageV001 storage $ = _getBaseStakingV2StorageV001();
		return $.reward.fakeRewardsTotal[id][rewardToken];
	}

	function allowedRewardTokens(address id, address rewardToken) external view returns (bool) {
		BaseStakingV2StorageV001 storage $ = _getBaseStakingV2StorageV001();
		return $.extraInfo.allowedRewardTokens[id][rewardToken];
	}

	function allowedRewardTokenList(address id) external view returns (address[] memory) {
		BaseStakingV2StorageV001 storage $ = _getBaseStakingV2StorageV001();
		return $.extraInfo.allowedRewardTokenList[id];
	}

	function sweepBase(address id) external {
		BaseStakingV2StorageV001 storage $ = _getBaseStakingV2StorageV001();
		StakingBasics.StakeInfo memory stake = stakings(id);
		require(stake.stakeType != Staking.StakeType.None, "BSV2: Not initialized");
		require(stake.flags.checkFlag(StakeFlags.Flag.IsBaseSweepable), "BSV2: Base not sweepable");
		address sweepTarget = $.extraInfo.sweepTargets[id];
		require(sweepTarget != address(0), "BSV2: No sweep target");
		uint256 currentSwept = $.state.stakeSwept[id];
		uint256 balance = $.state.stakedBalance[id];
		$.state.stakeSwept[id] = balance;
		sendToken($.baseInfo.baseToken[id], sweepTarget, balance-(currentSwept));
	}

	function sweepRewards(address id, address[] memory rewardTokens) external {
		BaseStakingV2StorageV001 storage $ = _getBaseStakingV2StorageV001();
		StakingBasics.StakeInfo memory stake = stakings(id);
		require(stake.stakeType != Staking.StakeType.None, "BSV2: Not initialized");
		require(stake.flags.checkFlag(StakeFlags.Flag.IsRewardSweepable), "BSV2: Reward not sweepable");
		require(block.timestamp > stake.endOfLife, "BSV2: Only after end of life");
		address sweepTarget = $.extraInfo.sweepTargets[id];
		require(sweepTarget != address(0), "BSV2: No sweep target");
		for(uint i=0; i<rewardTokens.length; i++) {
		_sweepSignleReward(id, rewardTokens[i], sweepTarget);
		}
	}

	function _sweepSignleReward(address id, address rewardToken, address sweepTarget) internal {
		BaseStakingV2StorageV001 storage $ = _getBaseStakingV2StorageV001();
		uint256 totalRewards = $.reward.rewardsTotal[id][rewardToken];
		uint256 toPay = totalRewards-($.reward.fakeRewardsTotal[id][rewardToken]);
		$.reward.fakeRewardsTotal[id][rewardToken] = totalRewards;
		sendToken(rewardToken, sweepTarget, toPay);
	}
		
	function baseToken(address id) external override view returns (address) {
		BaseStakingV2StorageV001 storage $ = _getBaseStakingV2StorageV001();
		return $.baseInfo.baseToken[id];
	}

	function isTokenizable(address id) external override view returns(bool) {
		return stakings(id).flags.checkFlag(StakeFlags.Flag.IsTokenizable);
	}

	function name(address id) external override view returns (string memory _name) {
		BaseStakingV2StorageV001 storage $ = _getBaseStakingV2StorageV001();
		_name = $.baseInfo.name[id];
	}

	function _getBaseStakingV2StorageV001() internal pure returns (BaseStakingV2StorageV001 storage $) {
		assembly {
			$.slot := BaseStakingV2StorageV001Location
		}
	}
}