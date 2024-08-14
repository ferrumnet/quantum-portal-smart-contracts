// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable, UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {SweepableUpgradeable} from "foundry-contracts/contracts/contracts-upgradeable/common/SweepableUpgradeable.sol";
import {IStakeV2, Staking} from "../../staking/interfaces/IStakeV2.sol";
import {IRewardPool} from "../../staking/interfaces/IRewardPool.sol";
import {StakeFlags, StakingBasics} from "../../staking/library/StakingBasics.sol";
import {VestingLibrary} from "../../staking/vesting/VestingLibrary.sol";
import {BaseStakingV2Upgradeable} from "./BaseStakingV2Upgradeable.sol";
import {WithGatewayUpgradeable} from "../quantumPortal/poc/utils/WithGatewayUpgradeable.sol";


/**
 * Open ended staking.
 * Supports multi-rewards.
 * Supports multi-stakes.
 * Supports min lock.
 * Cannot be tokenizable.
 */
contract StakeOpenUpgradeable is Initializable, UUPSUpgradeable, SweepableUpgradeable, BaseStakingV2Upgradeable, WithGatewayUpgradeable, IRewardPool {
    using StakeFlags for uint16;
    string constant public NAME = "FERRUM_STAKING_V2_OPEN";
    string constant public VERSION = "000.001";

    /// @custom:storage-location erc7201:ferrum.storage.stakeopen.001
    struct StakeOpenStorageV001 {
        mapping(address => mapping(address => uint256)) stakeTimes;
    }

    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.stakeopen.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant StakeOpenStorageV001Location = 0xd1e594e328d6b9dce40c5be8d3fbae8ce305ff69cc672a339e247103e00d4f00;

    function initialize(address _gateway, address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __WithGateway_init_unchained(_gateway);
        __BaseStakingV2_init();
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyGateway {}

    function initDefault(address token) external nonZeroAddress(token) {
        BaseStakingV2StorageV001 storage $b = _getBaseStakingV2StorageV001();
        StakingBasics.StakeInfo storage info = $b.stakings[token];
        require(
            $b.stakings[token].stakeType == Staking.StakeType.None,
            "SO: Already exists"
        );
        info.stakeType = Staking.StakeType.OpenEnded;
        $b.baseInfo.baseToken[token] = token;
        $b.baseInfo.name[token] = "Default Stake Pool";
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
        BaseStakingV2StorageV001 storage $b = _getBaseStakingV2StorageV001();
        require(allocation != 0, "StakeTimed: allocation is required");
        address allocator = $b.extraInfo.allocators[id];
        require(allocator != address(0), "StakeTimed: no allocator");
        // verifyAllocation(
        //     id,
        //     msg.sender,
        //     allocator,
        //     allocation,
        //     salt,
        //     allocatorSignature
        // );
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

    function _init(
        address token,
        string memory _name,
        address[] memory rewardTokens
    ) internal {
        BaseStakingV2StorageV001 storage $b = _getBaseStakingV2StorageV001();
        StakingBasics.StakeInfo storage info = $b.stakings[token];
        require(
            $b.stakings[token].stakeType == Staking.StakeType.None,
            "SO: Already exists"
        );
        info.stakeType = Staking.StakeType.OpenEnded;
        $b.baseInfo.baseToken[token] = token;
        $b.baseInfo.name[token] = _name;
        setAllowedRewardTokens(token, rewardTokens);
    }

    function _stake(
        address to,
        address id,
        uint256 allocation
    ) internal virtual returns (uint256) {
        BaseStakingV2StorageV001 storage $b = _getBaseStakingV2StorageV001();
        StakingBasics.StakeInfo memory info = $b.stakings[id];
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
        address token = $b.baseInfo.baseToken[id];
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
        BaseStakingV2StorageV001 storage $b = _getBaseStakingV2StorageV001();
        require(
            $b.extraInfo.allowedRewardTokens[id][rewardToken],
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
        BaseStakingV2StorageV001 storage $b = _getBaseStakingV2StorageV001();
        uint256 rewardAmount = sync(rewardToken);
        if (rewardAmount == 0) {
            return 0;
        } // No need to fail the transaction

        $b.reward.rewardsTotal[id][rewardToken] += rewardAmount;
        $b.reward.fakeRewardsTotal[id][rewardToken] += rewardAmount;
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
        StakeOpenStorageV001 storage $ = _getStakeOpenStorageV001();
        BaseStakingV2StorageV001 storage $b = _getBaseStakingV2StorageV001();
        uint256 lockSec = $b.extraInfo.lockSeconds[id];
        uint256 stakeTime = $.stakeTimes[id][staker];
        return stakeTime + lockSec;
    }

    function rewardOf(
        address id,
        address staker,
        address[] calldata rewardTokens
    ) external view virtual returns (uint256[] memory amounts) {
        BaseStakingV2StorageV001 storage $b = _getBaseStakingV2StorageV001();
        StakingBasics.StakeInfo memory info = $b.stakings[id];
        require(
            info.stakeType != Staking.StakeType.None,
            "SO: Stake not found"
        );
        uint256 balance = $b.state.stakes[id][staker];
        amounts = new uint256[](rewardTokens.length);
        if (balance == 0) {
            return amounts;
        }
        uint256 poolShareX128 = VestingLibrary.calculatePoolShare(
            balance,
            $b.state.stakedBalance[id]
        );
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            uint256 userFake = $b.reward.fakeRewards[id][staker][rewardTokens[i]];
            uint256 fakeTotal = $b.reward.fakeRewardsTotal[id][rewardTokens[i]];
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
        BaseStakingV2StorageV001 storage $b = _getBaseStakingV2StorageV001();
        return
            _withdrawRewards(
                to,
                id,
                msg.sender,
                $b.extraInfo.allowedRewardTokenList[id]
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
        StakeOpenStorageV001 storage $ = _getStakeOpenStorageV001();
        BaseStakingV2StorageV001 storage $b = _getBaseStakingV2StorageV001();
        StakingBasics.StakeInfo memory info = $b.stakings[id];
        require(
            info.stakeType == Staking.StakeType.OpenEnded,
            "SO: Not open ended stake"
        );
        uint256 _stakedBalance = $b.state.stakedBalance[id];
        address[] memory rewardTokens = $b.extraInfo.allowedRewardTokenList[id];

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address rewardToken = rewardTokens[i];
            uint256 fakeTotal = $b.reward.fakeRewardsTotal[id][rewardToken];
            uint256 curRew = _stakedBalance != 0
                ? amount * fakeTotal / _stakedBalance
                : fakeTotal;

            $b.reward.fakeRewards[id][staker][rewardToken] += curRew;

            if (_stakedBalance != 0) {
                $b.reward.fakeRewardsTotal[id][rewardToken] = fakeTotal + curRew;
            }
        }

        $b.state.stakedBalance[id] = _stakedBalance + amount;

        uint256 newStake = $b.state.stakes[id][staker] + amount;
        uint256 lastStakeTime = $.stakeTimes[id][staker];
        if (lastStakeTime != 0) {
            uint256 timeDrift = amount * (block.timestamp - lastStakeTime) / newStake;
            $.stakeTimes[id][staker] = lastStakeTime + timeDrift;
        } else {
            $.stakeTimes[id][staker] = block.timestamp;
        }
        $b.state.stakes[id][staker] = newStake;
    }

    function _withdraw(
        address to,
        address id,
        address staker,
        uint256 amount
    ) internal virtual nonZeroAddress(staker) nonZeroAddress(id) {
        BaseStakingV2StorageV001 storage $b = _getBaseStakingV2StorageV001();
        if (amount == 0) {
            return;
        }
        StakingBasics.StakeInfo memory info = $b.stakings[id];
        require(
            info.stakeType == Staking.StakeType.OpenEnded,
            "SO: Not open ended stake"
        );
        require(
            _withdrawTimeOf(id, staker) <= block.timestamp,
            "SO: too early to withdraw"
        );
        _withdrawOnlyUpdateStateAndPayRewards(to, id, staker, amount);
        sendToken($b.baseInfo.baseToken[id], to, amount);
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
        BaseStakingV2StorageV001 storage $b = _getBaseStakingV2StorageV001();
        uint256 userStake = $b.state.stakes[id][staker];
        require(amount <= userStake, "SO: Not enough balance");
        address[] memory rewardTokens = $b.extraInfo.allowedRewardTokenList[id];
        uint256 _stakedBalance = $b.state.stakedBalance[id];
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

        $b.state.stakes[id][staker] = userStake - amount;
        $b.state.stakedBalance[id] = _stakedBalance - amount;
        return amount;
    }

    function _withdrawPartialRewards(
        address to,
        address id,
        address staker,
        address rewardToken,
        uint256 poolShareX128
    ) internal {
        BaseStakingV2StorageV001 storage $b = _getBaseStakingV2StorageV001();
        uint256 userFake = $b.reward.fakeRewards[id][staker][rewardToken];
        uint256 fakeTotal = $b.reward.fakeRewardsTotal[id][rewardToken];
        (uint256 actualPay, uint256 fakeRewAmount) = _calcSingleRewardOf(
            poolShareX128,
            fakeTotal,
            userFake
        );

        if (fakeRewAmount > userFake) {
            // We have some rew to return. But we don't so add it back

            userFake = 0;
            $b.reward.fakeRewardsTotal[id][rewardToken] = fakeTotal - fakeRewAmount;
        } else {
            userFake = userFake - fakeRewAmount;
            $b.reward.fakeRewardsTotal[id][rewardToken] = fakeTotal - fakeRewAmount;
        }
        $b.reward.fakeRewards[id][staker][rewardToken] = userFake;
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
        BaseStakingV2StorageV001 storage $b = _getBaseStakingV2StorageV001();
        uint256 userStake = $b.state.stakes[id][staker];
        uint256 poolShareX128 = VestingLibrary.calculatePoolShare(
            userStake,
            $b.state.stakedBalance[id]
        );
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address rewardToken = rewardTokens[i];
            uint256 userFake = $b.reward.fakeRewards[id][staker][rewardToken];
            uint256 fakeTotal = $b.reward.fakeRewardsTotal[id][rewardToken];
            (uint256 actualPay, ) = _calcSingleRewardOf(
                poolShareX128,
                fakeTotal,
                userFake
            );

            $b.reward.rewardsTotal[id][rewardToken] -= actualPay;
            $b.reward.fakeRewards[id][staker][rewardToken] = userFake + actualPay;
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

    function _getStakeOpenStorageV001() private pure returns (StakeOpenStorageV001 storage $) {
        assembly {
            $.slot := StakeOpenStorageV001Location
        }
    }
}
