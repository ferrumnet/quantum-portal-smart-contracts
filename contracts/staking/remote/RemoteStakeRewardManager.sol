// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.2;

// import "./IRemoteStake.sol";
// import "foundary-contracts/contracts/common/IFerrumDeployer.sol";
// import "foundary-contracts/contracts/math/FullMath.sol";
// import "../library/TokenReceivable.sol";

// /**
//  * @notice Follows a remote asset as the stake and provides.
//  *     There is only one reward token per stake
//  * rewards.
//  * One reward token per stake token.
//  */
// abstract contract RemoteStakeRewardManager is TokenReceivable, IRemoteStake {
//     event Staked(address token, address staker_, uint256 stakedAmount_);
//     event PaidOut(
//         address token,
//         address rewardToken,
//         address staker_,
//         uint256 rewardAmount
//     );
//     address public immutable router;
//     address public immutable reflectionContract;

//     mapping(address => mapping(address => uint256)) public stakes;
//     mapping(address => mapping(address => uint256)) public fakeRewards;
//     mapping(address => uint256) public stakedBalance;
//     mapping(address => address) public rewardTokens;
//     mapping(address => uint256) public rewardsTotal;
//     mapping(address => uint256) public fakeRewardsTotal;

//     modifier onlyRouter() {
//         require(msg.sender == router, "RSRM: Only router method");
//         _;
//     }

//     constructor() {
//         (router, reflectionContract) = abi.decode(
//             IFerrumDeployer(msg.sender).initData(),
//             (address, address)
//         );
//     }

//     /**
//      @notice Adds reward and initializes the rewardToken.
//         can only be called by the router.
//      @param baseToken The base token
//      @param rewardToken The reward token
//      @return The added reward
//      */
//     function addReward(address baseToken, address rewardToken
//     ) external override onlyRouter returns (uint256) {
//         return _addMarginalReward(baseToken, rewardToken);
//     }

//     /**
//      @notice Adds reward to an initialized stake.
//      @param baseToken The base token
//      @return The added reward
//      */
//     function addRewardPublic(address baseToken
//     ) external returns (uint256) {
//         address rewardToken = rewardTokens[baseToken];
//         require(rewardToken != address(0), "RSRM: stake is not initialized");
//         return _addMarginalReward(baseToken, rewardToken);
//     }

//     /**
//      @notice Returns the accumulated fake reward
//      @param staker the staker
//      @param baseToken the base token
//      @return The accumulated fake reward
//      */
//     function fakeRewardOf(address staker, address baseToken
//     ) external view returns (uint256) {
//         return fakeRewards[baseToken][staker];
//     }

//     /**
//      @notice Returns someone's reward.
//        We will try to simulate a remote stake or withdraw in case 
//        users remote balance is different form out record.
//      @param staker The staker
//      @param token The token
//      @return The reward
//      */
//     function rewardOf(address staker, address token
//     ) external view virtual returns (uint256) {
//         uint256 userStake = stakes[token][staker];
//         uint256 userFake = fakeRewards[token][staker];
//         uint256 _stakedBalance = stakedBalance[token];
//         uint256 totalFake = fakeRewardsTotal[token];

//         uint256 newStake = getStake(reflectionContract, staker, token);
//         if (newStake > userStake) {
//             // sync for stake 
//             (uint256 userStakeDiff, uint256 userFakeRewDiff,
//                 uint256 stakedBalanceDiff, uint256 fakeRewTotalDiff) = _stakeStateChange(
//                     staker, token, userStake, newStake - userStake);
//             userStake += userStakeDiff;
//             userFake += userFakeRewDiff;
//             _stakedBalance += stakedBalanceDiff;
//             totalFake += fakeRewTotalDiff;
//         } else if (newStake < userStake) {
//             // sync for withdraw
//             uint256 actualPay;
//             (totalFake, userFake, userStake, _stakedBalance,
//                 actualPay) = _withdrawOnlyUpdateStateNoPayoutStateChange(
//                 staker, token, userStake, userStake - newStake);
//         }
//         if (userStake == 0) {
//             return 0;
//         }

//         return _calcWithdrawRewards(
//             userStake,
//             userFake,
//             _stakedBalance,
//             totalFake);
//     }

//     /**
//      @notice Withdraw rewards for another address. Only router can call this.
//          This is nonReentrant because getState is abstract. 
//          A bad implementation of getStake mixed with re-entry could be risky.
//      @param to Receiver of the rewards
//      @param baseToken The base token
//      @return The withdrawn reward
//      */
//     function withdrawRewardsFor(address to, address baseToken
//     ) external override onlyRouter nonReentrant returns (uint256) {
//         require(to != address(0), "RSRM: Bad address");
//         return _withdrawRewards(to, baseToken);
//     }

//     /**
//      @notice Withdraw rewards. This is nonReentrant because getState is abstract. 
//          A bad implementation of getStake mixed with re-entry could be risky.
//      @param baseToken The base token
//      @return The withdrawn reward
//      */
//     function withdrawRewards(address baseToken) external nonReentrant returns (uint256) {
//         require(msg.sender != address(0), "RSRM: Bad address");
//         return _withdrawRewards(msg.sender, baseToken);
//     }

//     /**
//      @notice Check the remote source, and compare the diff. Simulate a
//          stake or withdraw accordingly.
//      @param to The staker
//      @param token The token
//      */
//     function syncStake(address to, address token
//     ) external override nonReentrant {
//         _syncStake(to, token);
//     }

//     /**
//      @notice Returns the remote stake value
//      @param to The use address
//      @param token The stake base token
//      @return The remote stake amount
//      */
//     function userStake(
//         address to,
//         address token
//     ) external view returns (uint256) {
//         return getStake(reflectionContract, to, token);
//     }

//     /**
//      @notice Override this
//      @param source The source
//      @param to The receiver
//      @param token The token address
//      @return The stake amount
//      */
//     function getStake(
//         address source,
//         address to,
//         address token
//     ) internal virtual view returns (uint256);

//     /**
//      @notice Calculate rewards of
//      @param staker The staker
//      @param totalStaked_ The total amount staked
//      @param stake The stake amount
//      @param token The token
//      @return The reward amount
//      */
//     function _calcRewardOf(
//         address staker,
//         uint256 totalStaked_,
//         uint256 stake,
//         address token
//     ) internal view returns (uint256) {
//         if (stake == 0) {
//             return 0;
//         }
//         uint256 fr = fakeRewards[token][staker];
//         uint256 rew = _calcReward(totalStaked_, fakeRewardsTotal[token], stake);
//         return rew > fr ? rew - fr : 0; // Ignoring the overflow problem
//     }

//     /**
//      @notice Check the remote source, and compare the diff. Simulate a
//          stake or withdraw accordingly. This is nonReentrant as 
//          getState is abstract and we dont want a mix of syncState and withdraw
//          recursively
//      @param to The staker
//      @param token The token
//      */
//     function _syncStake(address to, address token
//     ) internal {
//         uint256 currentStake = stakes[token][to];
//         uint256 newStake = getStake(reflectionContract, to, token);
//         if (newStake > currentStake) {
//             uint256 amount = newStake - currentStake;
//             _stake(to, token, currentStake, amount);
//         } else if (newStake < currentStake) {
//             uint256 amount = currentStake - newStake;
//             _withdraw(to, token, currentStake, amount);
//         }
//     }


//     /**
//      @notice Simulate withdraw tokens
//      @param _staker The staker
//      @param token The token
//      @param current The current stake amount
//      @param amount The withdraw amount
//      */
//     function _withdraw(
//         address _staker,
//         address token,
//         uint256 current,
//         uint256 amount
//     ) internal virtual {
//         if (amount == 0) {
//             return;
//         }
//         _withdrawOnlyUpdateStateNoPayout(_staker, token, current, amount);
//     }

//     /**
//      @notice Formula:
//      Calc total rewards: balance * fake_total / stake_balance
//      Calc faked rewards: amount  * fake_total / stake_balance
//      Calc pay ratio: (total rewards - debt) / total rewards [ total rewards should NEVER be less than debt ]
//      Pay: pay ratio * faked rewards
//      Debt: Reduce by (fake rewards - pay)
//      total fake: reduce by fake rewards
//      Return the pay amount as rewards
//      @param _staker The staker
//      @param token The token
//      @param userStake The user stake amount
//      @param amount The amount
//      @return actualPay The actual pay amount
//      */
//     function _withdrawOnlyUpdateStateNoPayout(
//         address _staker,
//         address token,
//         uint256 userStake,
//         uint256 amount
//     ) internal virtual returns (uint256 actualPay) {
//         (
//             fakeRewardsTotal[token],
//             fakeRewards[token][_staker], , ,
//             actualPay
//         ) = _withdrawOnlyUpdateStateNoPayoutStateChange(
//             _staker, token, userStake, amount);
//         stakes[token][_staker] -= amount;
//         stakedBalance[token] -= amount;
//     }

//     /**
//      @notice Run withdraw without changing the states
//      @param _staker The staker
//      @param token The token
//      @param userStake The user stake amount
//      @param amount The withdraw amount
//      */
//     function _withdrawOnlyUpdateStateNoPayoutStateChange(
//         address _staker,
//         address token,
//         uint256 userStake,
//         uint256 amount
//     ) internal view virtual returns (
//             uint256 /*fakeRewardsTotal*/, uint256 /*userFake*/,
//             uint256 /*userStakes*/, uint256 /*stakedBalance*/, uint256 /*actualPay*/) {
//         require(amount <= userStake, "RSRM: Not enough balance");
//         uint256 userFake = fakeRewards[token][_staker];
//         uint256 fakeTotal = fakeRewardsTotal[token];
//         uint256 _stakedBalance = stakedBalance[token];
//         uint256 fakeRewAmount = _calculateFakeRewardAmount(
//             amount,
//             fakeTotal,
//             _stakedBalance
//         );

//         uint256 actualPay = 0;
//         if (fakeRewAmount > userFake) {
//             // We have some rew to return. But we don't so add it back
//             // any reward not already cleimed will be added back to this contract
//             actualPay = fakeRewAmount - userFake;
//             userFake = actualPay;
//             fakeTotal = fakeTotal - fakeRewAmount + actualPay;
//         } else {
//             userFake = userFake - fakeRewAmount;
//             fakeTotal = fakeTotal - fakeRewAmount;
//         }

//         return (
//             fakeTotal, userFake, userStake - amount, _stakedBalance - amount, actualPay
//         );
//     }

//     /**
//      @notice Simulate a stake
//      @param staker The staker
//      @param token The token
//      @param userStake The user stake
//      @param amount The stake amount
//      */
//     function _stake(
//         address staker,
//         address token,
//         uint256 userStake,
//         uint256 amount
//     ) internal {
//         _stakeUpdateStateOnly(staker, token, userStake, amount);
//         // To ensure total is only updated here. Not when simulating the stake.
//         emit Staked(token, staker, amount);
//     }

//     /**
//      @notice Run a stake. Only update the state
//      @param staker The staker
//      @param token The token
//      @param userStake The user stake
//      @param amount The stake amount
//      */
//     function _stakeUpdateStateOnly(
//         address staker,
//         address token,
//         uint256 userStake,
//         uint256 amount
//     ) internal {
//         (uint256 userStakeDiff, uint256 userFakeRewDiff,
//             uint256 stakedBalanceDiff, uint256 fakeRewTotalDiff) = _stakeStateChange(
//                 staker, token, userStake, amount);
        
//         stakes[token][staker] = userStake + userStakeDiff;
//         fakeRewards[token][staker] = fakeRewards[token][staker] + userFakeRewDiff;
//         stakedBalance[token] = stakedBalance[token] + stakedBalanceDiff;

//         if (fakeRewTotalDiff != 0) {
//             fakeRewardsTotal[token] = fakeRewardsTotal[token] + fakeRewTotalDiff;
//         }
//     }

//     /**
//      @notice Run a stake and change state
//      @param staker The staker
//      @param token The token
//      @param userStake The user stake
//      @param amount The stake amount
//      */
//     function _stakeStateChange(
//         address staker,
//         address token,
//         uint256 userStake,
//         uint256 amount
//     ) internal view returns(uint256 /*userStakeDiff*/, uint256 /*userFakeRewDiff*/,
//             uint256 /*stakedBalanceDiff*/, uint256 /*fakeRewTotalDiff*/) {
//         uint256 _stakedBalance = stakedBalance[token];
//         uint256 _fakeTotal = fakeRewardsTotal[token];
//         bool isNotNew = _stakedBalance != 0;
//         uint256 curRew = isNotNew
//             ? _calculateFakeRewardAmount(amount, _fakeTotal, _stakedBalance)
//             : _fakeTotal;
//         return (amount, curRew, amount, isNotNew ? curRew : 0);
//     }

//     /**
//      @notice Add a marginal reward
//      @param baseToken The base token
//      @param _rewardToken The reward token
//      @return The added reward amount
//      */
//     function _addMarginalReward(address baseToken, address _rewardToken
//     ) internal virtual returns (uint256) {
//         address rewardToken = rewardTokens[baseToken];
//         if (rewardToken == address(0) && _rewardToken != address(0)) {
//             rewardTokens[baseToken] = _rewardToken;
//             rewardToken = _rewardToken;
//         }
//         require(rewardToken != address(0), "RSRM: No reward token");
//         uint256 amount = sync(rewardToken);
//         if (amount == 0) {
//             return 0; // No reward to add. Its ok. No need to fail callers.
//         }
//         rewardsTotal[baseToken] = rewardsTotal[baseToken] + amount;
//         fakeRewardsTotal[baseToken] = fakeRewardsTotal[baseToken] + amount;
//         return amount;
//     }

//     /**
//      @notice Calculate the fake reward amount
//      @param amount The amount
//      @param baseFakeTotal The base fake total amount
//      @param baseStakeTotal The total stake amount
//      @return The fake reward amount
//      */
//     function _calculateFakeRewardAmount(
//         uint256 amount,
//         uint256 baseFakeTotal,
//         uint256 baseStakeTotal
//     ) internal pure returns (uint256) {
//         return FullMath.mulDiv(amount, baseFakeTotal, baseStakeTotal);
//     }

//     /**
//      @notice Withdraw the rewards
//      @param _staker The staker
//      @param token The token
//      @return The writhdraw rewards amount
//      */
//     function _withdrawRewards(address _staker, address token
//     ) internal returns (uint256) {
//         _syncStake(_staker, token);
//         uint256 userStake = stakes[token][_staker];
//         require(userStake != 0, "RSRM: user has no stake");
//         uint256 _stakedBalance = stakedBalance[token];
//         uint256 totalFake = fakeRewardsTotal[token];
//         uint256 userFake = fakeRewards[token][_staker];
//         uint256 actualPay = _calcWithdrawRewards(
//             userStake,
//             userFake,
//             _stakedBalance,
//             totalFake
//         );
//         rewardsTotal[token] = rewardsTotal[token] - actualPay;
//         fakeRewards[token][_staker] = userFake + actualPay;
//         if (actualPay != 0) {
//             address rewTok = rewardTokens[token];
//             sendToken(rewTok, _staker, actualPay);
//             emit PaidOut(token, rewTok, _staker, actualPay);
//         }
//         return actualPay;
//     }

//     /**
//      @notice Calculate the withdraw amount
//      @param _stakedAmount The staked amount
//      @param _userFakeRewards User fake rewards
//      @param _totalStaked The total staked amount
//      @param _totalFakeRewards The total fake rewards
//      @return The withdraw rewards
//      */
//     function _calcWithdrawRewards(
//         uint256 _stakedAmount,
//         uint256 _userFakeRewards,
//         uint256 _totalStaked,
//         uint256 _totalFakeRewards
//     ) internal pure returns (uint256) {
//         uint256 toPay = _calcReward(
//             _totalStaked,
//             _totalFakeRewards,
//             _stakedAmount
//         );
//         return toPay > _userFakeRewards ? toPay - _userFakeRewards : 0; // Ignore rounding issue
//     }

//     /**
//      @notice Caucualte rewards
//      @param total The total amount
//      @param fakeTotal The fake total amount
//      @param staked The staked amount
//      @return The rewards
//      */
//     function _calcReward(
//         uint256 total,
//         uint256 fakeTotal,
//         uint256 staked
//     ) internal pure returns (uint256) {
//         return FullMath.mulDiv(fakeTotal, staked, total);
//     }
// }
