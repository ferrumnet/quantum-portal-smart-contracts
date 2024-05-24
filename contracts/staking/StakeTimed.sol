// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./BaseStakingV2.sol";
import "./interfaces/IStakeV2.sol";
import "./interfaces/IRewardPool.sol";

contract StakeTimed is BaseStakingV2, IRewardPool {
    using StakeFlags for uint16;
    string constant VERSION = "000.001";
    constructor() EIP712("FERRUM_STAKING_V2_TIMED", VERSION) Ownable(msg.sender) { }

    function stakeWithAllocation(
        address staker,
        address id,
        uint256 allocation,
        bytes32 salt,
        bytes calldata allocatorSignature
        ) external override virtual
        returns (uint256) {
        require(allocation != 0, "StakeTimed: allocation is required");
        address allocator = extraInfo.allocators[id];
        require(allocator != address(0), "StakeTimed: no allocator");
        verifyAllocation(id, msg.sender, allocator, allocation, salt, allocatorSignature);
        return _stakeTimed(staker, id, allocation);
    }

    function stake(address to, address id) external override virtual
        returns (uint256 stakeAmount) {
        stakeAmount = _stakeTimed(to, id, 0);
    }
    
    function _stakeTimed(
        address staker,
        address id,
        uint256 allocation) internal virtual 
        returns (uint256 stakeAmount) {
        // check the amount to be staked
        // For pay per transfer tokens we limit the cap on incoming tokens for simplicity. This might
        // mean that cap may not necessary fill completely which is ok.
        require(id != address(0), "ST: id is required");
        require(staker != address(0), "ST: staker is required");

        // Validate the stake
        StakingBasics.StakeInfo memory info = stakings[id];
        require(info.stakeType == Staking.StakeType.Timed || info.stakeType == Staking.StakeType.PublicSale,
            "ST: bad stake type");
        require(info.contribStart >= block.timestamp && info.contribEnd <= block.timestamp, "ST: Bad timing for stake");
        require(!info.flags.checkFlag(StakeFlags.Flag.IsAllocatable) || allocation != 0, "ST: No allocation"); // Break early to save gas for allocatable stakes

        address tokenAddress = baseInfo.baseToken[id];
        uint256 stakingCap = baseInfo.cap[id];
        uint256 stakedBalance = state.stakedBalance[id];
        stakeAmount = sync(tokenAddress);
        require(stakeAmount != 0, "ST: Nothing to stake");
        require(stakingCap == 0 || stakeAmount+(stakedBalance) <= stakingCap, "ST: Cap reached");
        emit Staked(id, tokenAddress, staker, stakeAmount);

        // Transfer is completed
        uint256 userStake = state.stakes[id][staker]+(stakeAmount);
        require(!info.flags.checkFlag(StakeFlags.Flag.IsAllocatable) || userStake <= allocation, "ST: Not enough allocation");
        state.stakes[id][staker] = userStake;
        state.stakedBalance[id] = stakedBalance+(userStake);
    }

		/**
		 * @dev default stake id for any token, would be a staking with the same id
		 */
		function addMarginalReward(address rewardToken)
		external override returns (uint256) {
			return _addReward(rewardToken, rewardToken);
		}

		function addMarginalRewardToPool(address id, address rewardToken)
		external override returns (uint256) {
			return _addReward(id, rewardToken);
		}

    function addReward(address id, address rewardToken) 
    external returns (uint256) {
			return _addReward(id, rewardToken);
    }

    function _addReward(address id, address rewardToken) 
    internal returns (uint256 rewardAmount) {
        rewardAmount = sync(rewardToken);
        if (rewardAmount == 0) { return 0; } // No need to fail the transaction
        reward.rewardsTotal[id][rewardToken] = reward.rewardsTotal[id][rewardToken]+(rewardAmount);
        emit RewardAdded(id, rewardToken, rewardAmount);
    }

    function calculateRewards(address to, address id, address[] calldata rewardTokens)
    external view virtual nonZeroAddress(to) nonZeroAddress(id) returns (uint256[] memory amounts) {
        StakingBasics.StakeInfo memory info = stakings[id];
        require(info.stakeType != Staking.StakeType.None, "StakeTimed: Stake not found");
        if (block.timestamp > info.endOfLife) {
            return new uint256[](0); // No more rewards are paid after end of life.
        }
        uint256 balance = state.stakes[id][to];
        require(balance != 0, "StakeTimed: no balance");
        amounts = new uint256[](rewardTokens.length);
        uint256 poolShareX128 = VestingLibrary.calculatePoolShare(balance,
            state.stakedBalance[id]);
        for(uint i=0; i<rewardTokens.length; i++) {
            amounts[i] =
            _calcSingleReward2(
                to,
                id,
                block.timestamp,
                balance,
                poolShareX128,
                info.contribEnd,
                rewardTokens[i]);
        }
    }

    /**
     * Withdraws the rewards for the user.
     * Rewards for timed staking is a bit diff from the rewards for open ended staking.
     * Timed staking works based on the vesting schedule.
     * Make sure the formula works based on the share of stakes.
     * Withdrawn rewards will be added to users fakeRewards to allow several withdrawals.
     */
    function _takeRewards(
        address to,
        address id,
        address staker,
        address[] calldata rewardTokens,
        uint256 userBalance,
        uint256 withdrawAmount,
        StakingBasics.StakeInfo memory info)
    internal virtual returns (uint256[] memory rewards, bool linearBase) {
        {
        if (block.timestamp > info.endOfLife) {
            emit RewardPaid(id, staker, to, new address[](0), new uint256[](0));
            return (rewards, false); // No more rewards are paid after end of life.
        }

        }

        linearBase = false;
        rewards = new uint256[](rewardTokens.length);
        uint256 poolShareX128 = VestingLibrary.calculatePoolShare(userBalance,
            state.stakedBalance[id]);
        uint256 remainingStakeRatioX128 = withdrawAmount == 0 ? 0 :
            VestingLibrary.calculateRemainingStakeRatioX128(userBalance, withdrawAmount);
        for(uint i=0; i<rewardTokens.length; i++) {
            address rt = rewardTokens[i];
            bool _singleLinBase;
            (rewards[i], _singleLinBase) = _takeSingleReward(
                to,
                id,
                staker,
                userBalance,
                remainingStakeRatioX128,
                poolShareX128,
                info.contribEnd,
                rt);
            linearBase = linearBase || _singleLinBase;
        }
        emit RewardPaid(id, staker, to, rewardTokens, rewards);
    }

    function _calcSingleReward2(
        address to,
        address id,
        uint256 blockTime,
        uint256 userBalance,
        uint256 poolShareX128,
        uint256 contribEnd,
        address rewardToken)
        internal view returns (uint256 payAmount) {
        uint256 i1; uint256 i2;
        bool linearBase; uint256 amount;
        (amount, payAmount, linearBase, i1, i2) = _calcSingleReward(to, id, blockTime, userBalance,
            poolShareX128, contribEnd, rewardToken);
    }

    function _calcMaxApyRew(
        address id,
        uint256 blockTime,
        uint256 contribEnd,
        uint256 poolShareX128,
        uint256 userBalance,
        address rewardToken
        
    ) internal view returns (uint256 amount, bool linearBase) {
        uint256 maxApyRew;
        uint256 r;
        VestingLibrary.VestingItem[] memory vi = vesting.items[id][rewardToken];
        {
            uint256 maxApyX128 = vesting.maxApyX128[id][rewardToken];
            maxApyRew = maxApyX128 == 0 ? 0 : VestingLibrary.calculateMaxApy(
                contribEnd, blockTime, maxApyX128, userBalance);
            r = reward.rewardsTotal[id][rewardToken];
        }
        (amount, linearBase) = VestingLibrary.calculateVestedRewards(
            poolShareX128,
            contribEnd,
            blockTime,
            maxApyRew,
            r,
            vi);
    }

    function _calcSingleReward(
        address to,
        address id,
        uint256 blockTime,
        uint256 userBalance,
        uint256 poolShareX128,
        uint256 contribEnd,
        address rewardToken)
        internal view returns (uint256 amount, uint256 payAmount, bool linearBase,
            uint256 fakeRewardUser, uint256 fakeRewardTotal) {
        // VestingLibrary.VestingItem[] memory vest = vesting.items[id][rewardToken];
        // require(vest.length != 0 && vest[0].endTime != 0, "StakeTimed: No vesting configured");

        (amount, linearBase) = _calcMaxApyRew(id, blockTime, contribEnd, poolShareX128, userBalance, rewardToken);
        if (amount != 0) {
            // Chek the amount of reward paid so far to the user.
            fakeRewardUser = reward.fakeRewards[id][rewardToken][to];
            fakeRewardTotal = reward.fakeRewardsTotal[id][rewardToken];
            payAmount = Math.min(
                reward.rewardsTotal[id][rewardToken]-(fakeRewardTotal), // staking reward balance
                amount > fakeRewardUser ? amount-(fakeRewardUser) : 0); // actual reward to be paid
        }
    }

    function _takeSingleReward(
        address to,
        address id,
        address staker,
        uint256 userBalance,
        uint256 remainingStakeRatioX128, // Remaining after withdraw
        uint256 poolShareX128,
        uint256 contribEnd,
        address rewardToken) internal virtual returns (uint256 payAmount, bool linearBase) {
        uint256 amount = 0;
        uint256 fakeRewardUser; uint256 fakeRewardTotal;
        (amount, payAmount, linearBase, fakeRewardUser, fakeRewardTotal) = _calcSingleReward(staker, id, block.timestamp, userBalance,
            poolShareX128, contribEnd, rewardToken);

        if (payAmount != 0) {
            if (remainingStakeRatioX128 == 0) {
                reward.fakeRewards[id][rewardToken][staker] = fakeRewardUser+(payAmount);
            } else {
                // Don't store anything to save gas. We will change fakeRewards further down.
            }
            reward.fakeRewardsTotal[id][rewardToken] = fakeRewardTotal+(payAmount);
            sendToken(rewardToken, to, payAmount);
        }

        if (remainingStakeRatioX128 != 0) {
            // If we are dealing with a withdraw, we need to reset the fakeRewards (owe).
            // The withdraw vs takeRwards relationship. (withdraw amount ratio to balance: w)
            // 1- amount = takeReward for the total user balance.
            // 3- pay rewards (amount - owe) [above]
            // 4- pay base, balance * w, and reduce the base [later]
            // 5- owe = amount * (1-w)
            // No 5 ensures user doesn't get any rewards (duplicate) after withdraw.

            // At this point we assume all the rewards are paid. If there is no money to pay
            // the rewards, user will lose the unpaid rewards.
            // @dev UI to make sure warn user about this.
            reward.fakeRewards[id][rewardToken][staker] =
                VestingLibrary.calculateFakeRewardForWithdraw(amount, remainingStakeRatioX128);
        }
    }

    bytes32 constant TAKE_REWARDS_WITH_SIGNATURE_METHOD = keccak256(
        "TakeRewardsWithSignature(address to,address id,address[] rewardTokens,bytes32 salt,uint64 expiry)");
    function takeRewardsWithSignature(
        address to,
        address id,
        address staker,
        address[] calldata rewardTokens,
        bytes32 salt,
        uint64 expiry,
        bytes memory signature) external returns (uint256[] memory) {
        bytes32 message = keccak256(abi.encode(
            TAKE_REWARDS_WITH_SIGNATURE_METHOD,
            to,
            id,
            rewardTokens,
            salt,
            expiry));
        address _signer = signerUnique(message, signature);
        require(_signer == staker, "ST: Invalid signer");
        return _takeRewardsOnly(to, id, staker, rewardTokens);
    }

    function takeRewards(
        address id,
        address[] calldata rewardTokens) external returns (uint256[] memory) {
        return _takeRewardsOnly(msg.sender, id, msg.sender, rewardTokens);
    }

    function _takeRewardsOnly(address to, address id, address staker, address[] calldata rewardTokens)
    internal returns (uint256[] memory rewards) {
        // Calculate the reward amount, update the state, and pay the rewards
        uint256 userBalance = state.stakes[id][staker];
        require(userBalance != 0, "ST: Not enough stake");
        StakingBasics.StakeInfo memory info = stakings[id];
        require(info.stakeType == Staking.StakeType.Timed || info.stakeType == Staking.StakeType.PublicSale,
            "ST: Stake not found or bad type");
        bool ignore;
        (rewards, ignore) = _takeRewards(to, id, staker, rewardTokens, userBalance, 0, info);
    }

    function withdraw(address id, address[] calldata rewardTokens, uint256 amount)
    external returns (uint256 actualAmount, uint256[] memory rewardAmount) {
        // return _withdraw(msg.sender, msg.sender, id, msg.sender, rewardTokens, amount); 
    }

    bytes32 constant WITHDRAW_WITH_SIGNATURE_METHOD = keccak256(
        "WithdrawWithSignature(address to,address rewardsTo,address id,address[] rewardTokens,uint256 amount,bytes32 salt,uint64 expiry)");
    function withdrawWithSignature(
        address to,
        address rewardsTo,
        address id,
        address staker,
        address[] calldata rewardTokens,
        uint256 amount,
        bytes32 salt,
        uint64 expiry,
        bytes memory signature)
    external returns (uint256 actualAmount, uint256[] memory rewardAmount) {
        bytes32 message = keccak256(abi.encode(
            WITHDRAW_WITH_SIGNATURE_METHOD,
            to,
            rewardsTo,
            id,
            rewardTokens,
            amount,
            salt));
        address _signer = signerUnique(message, signature);
        require(_signer == staker, "ST: Invalid signer");
        return _withdraw(to, rewardsTo, id, staker, rewardTokens, amount); 
    }

    function _withdraw(
        address to,
        address rewardsTo,
        address id,
        address staker,
        address[] calldata rewardTokens,
        uint256 amount)
    internal virtual returns (uint256 toPay, uint256[] memory rewardAmount) {
        // Calculate the reward amount, update the state, and pay the rewards
        uint256 debt= state.stakeDebts[id][staker];
        toPay = amount-(debt);

        {
            uint256 userBalance = state.stakes[id][staker];
            require(userBalance >= amount, "ST: Not enough stake");

            StakingBasics.StakeInfo memory info = stakings[id];
            require(info.stakeType == Staking.StakeType.Timed, "ST: Stake not found or bad type");
            ensureWithdrawAllowed(info);
            bool linearBase;
            (rewardAmount, linearBase) =
                _takeRewards(rewardsTo, id, staker, rewardTokens, userBalance, amount, info);
            if (linearBase) {
                // Do not reduce the withdraw amount for linear base. User should get rewarded for 
                // their full balance.
                state.stakeDebts[id][staker] = debt+(toPay);
            } else {
                state.stakes[id][staker] = userBalance-(toPay);
            }
        }

        if (toPay != 0) {
            address token = baseInfo.baseToken[id];
            emit BasePaid(id, staker, to, token, toPay);
            sendToken(token, to, toPay);
        }
    }

    function setVestingSchedule(
        address id,
        address rewardToken,
        uint256 maxApyX10000,
        uint256 baseRewRatioX128, // Price of base over rew. E.g. rew FRMX, base FRM => $0.5*10^6/(10,000*10^18)
        uint32[] calldata endTimes,
        uint128[] calldata amounts,
        VestingLibrary.PeriodType[] calldata periodTypes) onlyAdmin(id) nonZeroAddress(rewardToken) nonZeroAddress(id) external {
        StakingBasics.StakeInfo memory info = stakings[id];
        require(info.stakeType != Staking.StakeType.None, "VL: staking not found");
        require(info.configHardCutOff > block.timestamp, "VL: admin deadline");
        if (info.restrictedRewards) {
            // Make sure the reward is configured in the stake.
            require(extraInfo.allowedRewardTokens[id][rewardToken], "VL: reward token not allowed");
        }
        VestingLibrary.setVestingSchedule(id, rewardToken, maxApyX10000, baseRewRatioX128,
            endTimes, amounts, periodTypes, vesting);
    }
}
