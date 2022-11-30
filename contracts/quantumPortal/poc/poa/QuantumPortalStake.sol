// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./QuantumPortalAuthorityMgr.sol";
import "../../../staking/StakeOpen.sol";

/**
 @notice The QP stake, is a special type of open staking, with two exceptions:
    1 - Unstake will move assets to a locked state, for a period.
    2 - Authorities can slash
 */
contract QuantumPortalStake is StakeOpen {
    struct WithdrawItem {
        uint64 opensAt;
        uint128 amount;
    }
    struct Pair {
        uint64 start;
        uint64 end;
    }

    uint64 constant WITHDRAW_LOCK = 30 * 3600 * 24;
    address constant DEFAULT_ID = address(1);
    address slashTarget;
    IQuantumPortalAuthorityMgr auth;
    mapping(address => Pair) public withdrawItemsQueueParam;
    mapping(address => mapping(uint256 => WithdrawItem))
        public withdrawItemsQueue;

    /**
     @notice This will first, release all the available withdraw items, 
     */
    function _withdraw(
        address to,
        address id,
        address staker,
        uint256 amount
    ) internal override nonZeroAddress(staker) {
        require(id == DEFAULT_ID, "QPS: bad id");
        if (amount == 0) {
            return;
        }
        // Below assumed
        // StakingBasics.StakeInfo memory info = stakings[id];
        // require(
        //     info.stakeType == Staking.StakeType.OpenEnded,
        //     "SO: Not open ended stake"
        // );
        releaseWithdrawItems(staker, staker, 0);
        _withdrawOnlyUpdateStateAndPayRewards(to, id, staker, amount);

        // Lock balance
        WithdrawItem memory wi = WithdrawItem({
            opensAt: uint64(block.timestamp) + WITHDRAW_LOCK,
            amount: uint128(amount)
        });
        pushToQueue(staker, wi);
    }

    function releaseWithdrawItems(
        address staker,
        address receiver,
        uint256 max
    ) public nonReentrant returns (uint256 total) {
        require(staker != address(0), "QPS: staker requried");
        address token = baseInfo.baseToken[DEFAULT_ID];
        (Pair memory pair, WithdrawItem memory wi) = peekQueue(staker);
        while (wi.opensAt != 0 && wi.opensAt < block.timestamp) {
            popFromQueue(staker, pair);
            sendToken(token, receiver, wi.amount);
            total += wi.amount;
            if (max != 0 && total >= max) {
                // Shortcut if total greater than 0
                return total;
            }
            (pair, wi) = peekQueue(staker);
        }
    }

    bytes32 constant SLASH_STAKE =
        keccak256("SlashStake(address user,uint256 amount,bytes32 salt,int64 expiry)");

    function slashUser(
        address user,
        uint256 amount,
        bytes32 salt,
        uint64 expiry,
        bytes memory multiSignature
    ) external returns (uint256) {
        bytes32 message = keccak256(abi.encode(SLASH_STAKE, user, amount));
        auth.validateAuthoritySignature(IQuantumPortalAuthorityMgr.Action.SLASH, message, salt, expiry, multiSignature);
        amount = slashWithdrawItem(user, amount);
        return slashStake(user, amount);
    }

    function slashStake(address staker, uint256 amount)
        internal
        returns (uint256 remaining)
    {
        uint256 stake = state.stakes[DEFAULT_ID][staker];
        stake = amount < stake ? amount : stake;
        remaining = amount - stake;
        _withdrawOnlyUpdateStateAndPayRewards(
            slashTarget,
            DEFAULT_ID,
            staker,
            stake
        );
        address token = baseInfo.baseToken[DEFAULT_ID];
        sendToken(token, slashTarget, amount);
    }

    function slashWithdrawItem(address staker, uint256 amount)
        internal
        returns (uint256)
    {
        uint256 released = releaseWithdrawItems(staker, slashTarget, amount);
        return amount > released ? amount - released : 0;
    }

    function pushToQueue(address staker, WithdrawItem memory wi) private {
        uint256 end = withdrawItemsQueueParam[staker].end;
        withdrawItemsQueueParam[staker].end = uint64(end) + 1;
        withdrawItemsQueue[staker][end + 1] = wi;
    }

    function popFromQueue(address staker, Pair memory pair) private {
        withdrawItemsQueueParam[staker].start = pair.start + 1;
        delete withdrawItemsQueue[staker][pair.start];
    }

    function peekQueue(address staker)
        private
        returns (Pair memory pair, WithdrawItem memory wi)
    {
        pair = withdrawItemsQueueParam[staker];
        wi = withdrawItemsQueue[staker][pair.start];
    }
}
