// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./interfaces/IStakeV2.sol";
import "./interfaces/IRewardPool.sol";
import "foundry-contracts/contracts/contracts/common/Sweepable.sol";
import "./BaseStakingV2.sol";

/**
 * Open ended staking.
 * Supports multi-rewards.
 * Supports multi-stakes.
 * Supports min lock.
 * Cannot be tokenizable.
 */
contract StakeOpen is Sweepable, BaseStakingV2, IRewardPool {
    using StakeFlags for uint16;
    mapping(address => mapping(address => uint256)) internal stakeTimes;

    string constant public VERSION = "000.001";

    constructor() EIP712("FERRUM_STAKING_V2_OPEN", VERSION) Ownable(msg.sender) {}

    function initDefault(address token) external nonZeroAddress(token) {
        StakingBasics.StakeInfo storage info = stakings[token];
        require(
            stakings[token].stakeType == Staking.StakeType.None,
            "SO: Already exists"
        );
        info.stakeType = Staking.StakeType.OpenEnded;
        baseInfo.baseToken[token] = token;
        baseInfo.name[token] = "Default Stake Pool";
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = token;
        setAllowedRewardTokens(token, rewardTokens);
    }

    function init(address token, string memory _name, address[] calldata rewardTokens) external nonZeroAddress(token) onlyOwner {
        _init(token, _name, rewardTokens);
    }

    function stakeWithAllocation(
        address staker,
        address id,
        uint256 allocation,
        bytes32 salt,
        bytes calldata allocatorSignature
    ) external virtual override returns (uint256) {
        require(allocation != 0, "StakeTimed: allocation is required");
        address allocator = extraInfo.allocators[id];
        require(allocator != address(0), "StakeTimed: no allocator");
        verifyAllocation(
            id,
            msg.sender,
            allocator,
            allocation,
            salt,
            allocatorSignature
        );
        return _stake(staker, id, allocation);
    }

    function stake(address to, address id)
        external
        virtual
        override
        returns (uint256 stakeAmount)
    {
        stakeAmount = _stake(to, id, 0);
    }

    /**
     * Default stake is an stake with the id of the token.
     */
    function stakeFor(address to, address id)
        external
        virtual
        nonZeroAddress(to)
        nonZeroAddress(id)
        returns (uint256)
    {
        return _stake(to, id, 0);
    }

    function _init(address token, string memory _name, address[] memory rewardTokens
    ) internal {
        StakingBasics.StakeInfo storage info = stakings[token];
        require(
            stakings[token].stakeType == Staking.StakeType.None,
            "SO: Already exists"
        );
        info.stakeType = Staking.StakeType.OpenEnded;
        baseInfo.baseToken[token] = token;
        baseInfo.name[token] = _name;
        setAllowedRewardTokens(token, rewardTokens);
    }

    function _stake(
        address to,
        address id,
        uint256 allocation
    ) internal virtual returns (uint256) {
        StakingBasics.StakeInfo memory info = stakings[id];
        require(
            info.stakeType == Staking.StakeType.OpenEnded,
            "SO: Not open ended stake"
        );
        require(
            !info.flags.checkFlag(StakeFlags.Flag.IsAllocatable) ||
                allocation != 0,
            "SO: No allocation"
        ); // Break early to save gas for allocatable stakes
        require(to != address(0), "SO: stake to zero");
        address token = baseInfo.baseToken[id];
        uint256 amount = sync(token);
        require(amount != 0, "SO: amount is required");
        require(
            !info.flags.checkFlag(StakeFlags.Flag.IsAllocatable) ||
                amount <= allocation,
            "SO: Not enough allocation"
        );
        _stakeUpdateStateOnly(to, id, amount);
        return amount;
    }

    /**
     * First send the rewards to this contract, then call this method.
     * Designed to be called by smart contracts.
     */
    function addMarginalReward(address rewardToken)
        external
        override
        returns (uint256)
    {
        return _addReward(rewardToken, rewardToken);
    }

    function addMarginalRewardToPool(address id, address rewardToken)
        external
        override
        returns (uint256)
    {
        require(
            extraInfo.allowedRewardTokens[id][rewardToken],
            "SO: rewardToken not valid for this stake"
        );
        return _addReward(id, rewardToken);
    }

    function _addReward(address id, address rewardToken)
        internal
        virtual
        nonZeroAddress(id)
        nonZeroAddress(rewardToken)
        returns (uint256)
    {
        uint256 rewardAmount = sync(rewardToken);
        if (rewardAmount == 0) {
            return 0;
        } // No need to fail the transaction

        reward.rewardsTotal[id][rewardToken] = reward
        .rewardsTotal[id][rewardToken] + rewardAmount;
        reward.fakeRewardsTotal[id][rewardToken] = reward
        .fakeRewardsTotal[id][rewardToken] + rewardAmount;
        emit RewardAdded(id, rewardToken, rewardAmount);
        return rewardAmount;
    }

    function withdrawTimeOf(address id, address staker)
        external
        view
        returns (uint256)
    {
        return _withdrawTimeOf(id, staker);
    }

    function _withdrawTimeOf(address id, address staker)
        internal
        view
        returns (uint256)
    {
        uint256 lockSec = extraInfo.lockSeconds[id];
        uint256 stakeTime = stakeTimes[id][staker];
        return stakeTime + lockSec;
    }

    function rewardOf(
        address id,
        address staker,
        address[] calldata rewardTokens
    ) external view virtual returns (uint256[] memory amounts) {
        StakingBasics.StakeInfo memory info = stakings[id];
        require(
            info.stakeType != Staking.StakeType.None,
            "SO: Stake not found"
        );
        uint256 balance = state.stakes[id][staker];
        amounts = new uint256[](rewardTokens.length);
        if (balance == 0) {
            return amounts;
        }
        uint256 poolShareX128 = VestingLibrary.calculatePoolShare(
            balance,
            state.stakedBalance[id]
        );
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            uint256 userFake = reward.fakeRewards[id][staker][rewardTokens[i]];
            uint256 fakeTotal = reward.fakeRewardsTotal[id][rewardTokens[i]];
            (amounts[i], ) = _calcSingleRewardOf(
                poolShareX128,
                fakeTotal,
                userFake
            );
        }
    }

    function withdrawRewards(address to, address id)
        external
        virtual
        nonZeroAddress(to)
        nonZeroAddress(id)
    {
        return
            _withdrawRewards(
                to,
                id,
                msg.sender,
                extraInfo.allowedRewardTokenList[id]
            );
    }

    /**
     * First withdraw all rewards, than withdarw it all, then stake back the remaining.
     */
    function withdraw(
        address to,
        address id,
        uint256 amount
    ) external virtual {
        _withdraw(to, id, msg.sender, amount);
    }

    function _stakeUpdateStateOnly(
        address staker,
        address id,
        uint256 amount
    ) internal {
        StakingBasics.StakeInfo memory info = stakings[id];
        require(
            info.stakeType == Staking.StakeType.OpenEnded,
            "SO: Not open ended stake"
        );
        uint256 _stakedBalance = state.stakedBalance[id];
        address[] memory rewardTokens = extraInfo.allowedRewardTokenList[id];

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address rewardToken = rewardTokens[i];
            uint256 fakeTotal = reward.fakeRewardsTotal[id][rewardToken];
            uint256 curRew = _stakedBalance != 0
                ? amount * fakeTotal / _stakedBalance
                : fakeTotal;

            reward.fakeRewards[id][staker][rewardToken] = reward
            .fakeRewards[id][staker][rewardToken] + curRew;

            if (_stakedBalance != 0) {
                reward.fakeRewardsTotal[id][rewardToken] = fakeTotal + curRew;
            }
        }

        state.stakedBalance[id] = _stakedBalance + amount;

        uint256 newStake = state.stakes[id][staker] + amount;
        uint256 lastStakeTime = stakeTimes[id][staker];
        if (lastStakeTime != 0) {
            uint256 timeDrift = amount * (block.timestamp - lastStakeTime) / newStake;
            stakeTimes[id][staker] = lastStakeTime + timeDrift;
        } else {
            stakeTimes[id][staker] = block.timestamp;
        }
        state.stakes[id][staker] = newStake;
    }

    function _withdraw(
        address to,
        address id,
        address staker,
        uint256 amount
    ) internal virtual nonZeroAddress(staker) nonZeroAddress(id) {
        if (amount == 0) {
            return;
        }
        StakingBasics.StakeInfo memory info = stakings[id];
        require(
            info.stakeType == Staking.StakeType.OpenEnded,
            "SO: Not open ended stake"
        );
        require(
            _withdrawTimeOf(id, staker) <= block.timestamp,
            "SO: too early to withdraw"
        );
        _withdrawOnlyUpdateStateAndPayRewards(to, id, staker, amount);
        sendToken(baseInfo.baseToken[id], to, amount);
        // emit PaidOut(tokenAddress, staker, amount);
    }

    /*
     * @dev: Formula:
     * Calc total rewards: balance * fake_total / stake_balance
     * Calc faked rewards: amount  * fake_total / stake_balance
     * Calc pay ratio: (total rewards - debt) / total rewards [ total rewards should NEVER be less than debt ]
     * Pay: pay ratio * faked rewards
     * Debt: Reduce by (fake rewards - pay)
     * total fake: reduce by fake rewards
     * Return the pay amount as rewards
     */
    function _withdrawOnlyUpdateStateAndPayRewards(
        address to,
        address id,
        address staker,
        uint256 amount
    ) internal virtual returns (uint256) {
        uint256 userStake = state.stakes[id][staker];
        require(amount <= userStake, "SO: Not enough balance");
        address[] memory rewardTokens = extraInfo.allowedRewardTokenList[id];
        uint256 _stakedBalance = state.stakedBalance[id];
        uint256 poolShareX128 = VestingLibrary.calculatePoolShare(
            amount,
            _stakedBalance
        );

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            _withdrawPartialRewards(
                to,
                id,
                staker,
                rewardTokens[i],
                poolShareX128
            );
        }

        state.stakes[id][staker] = userStake - amount;
        state.stakedBalance[id] = _stakedBalance - amount;
        return amount;
    }

    function _withdrawPartialRewards(
        address to,
        address id,
        address staker,
        address rewardToken,
        uint256 poolShareX128
    ) internal {
        uint256 userFake = reward.fakeRewards[id][staker][rewardToken];
        uint256 fakeTotal = reward.fakeRewardsTotal[id][rewardToken];
        (uint256 actualPay, uint256 fakeRewAmount) = _calcSingleRewardOf(
            poolShareX128,
            fakeTotal,
            userFake
        );

        if (fakeRewAmount > userFake) {
            // We have some rew to return. But we don't so add it back

            userFake = 0;
            reward.fakeRewardsTotal[id][rewardToken] = fakeTotal - fakeRewAmount;
        } else {
            userFake = userFake - fakeRewAmount;
            reward.fakeRewardsTotal[id][rewardToken] = fakeTotal - fakeRewAmount;
        }
        reward.fakeRewards[id][staker][rewardToken] = userFake;
        if (actualPay != 0) {
            sendToken(rewardToken, to, actualPay);
        }
    }

    function _withdrawRewards(
        address to,
        address id,
        address staker,
        address[] memory rewardTokens
    ) internal {
        uint256 userStake = state.stakes[id][staker];
        uint256 poolShareX128 = VestingLibrary.calculatePoolShare(
            userStake,
            state.stakedBalance[id]
        );
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address rewardToken = rewardTokens[i];
            uint256 userFake = reward.fakeRewards[id][staker][rewardToken];
            uint256 fakeTotal = reward.fakeRewardsTotal[id][rewardToken];
            (uint256 actualPay, ) = _calcSingleRewardOf(
                poolShareX128,
                fakeTotal,
                userFake
            );

            reward.rewardsTotal[id][rewardToken] = reward
            .rewardsTotal[id][rewardToken] - actualPay;
            reward.fakeRewards[id][staker][rewardToken] = userFake + actualPay;
            if (actualPay != 0) {
                sendToken(rewardToken, to, actualPay);
            }
        }
        // emit PaidOut(tokenAddress, address(rewardToken), _staker, 0, actualPay);
    }

    function _calcSingleRewardOf(
        uint256 poolShareX128,
        uint256 _fakeRewardsTotal,
        uint256 userFake
    ) internal pure returns (uint256, uint256) {
        if (poolShareX128 == 0) {
            return (0, 0);
        }
        uint256 rew = VestingLibrary.calculateFakeRewardForWithdraw(
            _fakeRewardsTotal,
            poolShareX128
        );
        return (rew > userFake ? rew - userFake : 0, rew); // Ignoring the overflow problem
    }
}
