// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IQuantumPortalStake.sol";
import "./QuantumPortalAuthorityMgr.sol";
import "./Delegator.sol";
import "../../../staking/StakeOpen.sol";

import "hardhat/console.sol";

/**
 @notice The QP stake, is a special type of open staking, with two exceptions:
    1 - Unstake will move assets to a locked state, for a period.
    2 - Authorities can slash
 */
contract QuantumPortalStake is StakeOpen, Delegator, IQuantumPortalStake {
    struct WithdrawItem {
        uint64 opensAt;
        uint128 amount;
        address to;
    }
    struct Pair {
        uint64 start;
        uint64 end;
    }

    uint64 constant WITHDRAW_LOCK = 30 * 3600 * 24;
    address public override STAKE_ID;
    address slashTarget;
    IQuantumPortalAuthorityMgr public auth;
    mapping(address => Pair) public withdrawItemsQueueParam;
    mapping(address => mapping (uint => WithdrawItem)) public withdrawItemsQueue;

    constructor() {
        bytes memory _data = IFerrumDeployer(msg.sender).initData();
        (address token, address authority) = abi.decode(_data, (address, address));
        address[] memory tokens = new address[](1);
        tokens[0] = token;
        _init(token, "QP Stake", tokens);
        STAKE_ID = token;
        auth = IQuantumPortalAuthorityMgr(authority);
    }

    function delegatedStakeOf(address delegatee
    ) external override view returns (uint256) {
        require(delegatee != address(0), "QPS: delegatee required");
        ReverseDelegation memory rd = reverseDelegation[delegatee];
        if (rd.deleted == 1) {
            return 0;
        }
        address staker = rd.delegatee;
        require(staker != address(0), "QPS: delegatee not valid");
		return state.stakes[STAKE_ID][staker];
	}

    /**
     @notice This will only move items to the withdraw queue.
     */
    function _withdraw(
        address to,
        address id,
        address staker,
        uint256 amount
    ) internal override nonZeroAddress(staker) {
        require(id == STAKE_ID, "QPS: bad id");
        if (amount == 0) {
            return;
        }
        // Below assumed
        // StakingBasics.StakeInfo memory info = stakings[id];
        // require(
        //     info.stakeType == Staking.StakeType.OpenEnded,
        //     "SO: Not open ended stake"
        // );
        _withdrawOnlyUpdateStateAndPayRewards(to, id, staker, amount);

        // Lock balance
        WithdrawItem memory wi = WithdrawItem({
            opensAt: uint64(block.timestamp) + WITHDRAW_LOCK,
            amount: uint128(amount),
            to: to
        });
        pushToQueue(staker, wi);
    }

    /**
     * @notice Only staker can release WI. This is to allow staker to be a smart contract
     * and manage state when withdraw happens.
     * @param staker The staker.
     * @return paidTo Returns the list of payments.
     * @return amounts Returns the list of payments.
     */
    function releaseWithdrawItems(address staker
    ) external returns(address[] memory paidTo, uint256[] memory amounts) {
        require(staker != address(0), "QPS: staker requried");
        require(msg.sender == staker, "QPS: not owner");
        address token = baseInfo.baseToken[STAKE_ID];
        (Pair memory pair, WithdrawItem memory wi) = peekQueue(staker);
        paidTo = new address[](pair.end - pair.start);
        amounts = new uint256[](pair.end - pair.start);
        console.log("PEEKED", wi.opensAt, block.timestamp);
        uint i = 0;
        while(wi.opensAt != 0 && wi.opensAt < block.timestamp) {
            popFromQueue(staker, pair);
            console.log("Sending tokens ", wi.amount);
            sendToken(token, wi.to, wi.amount);
            paidTo[i] = wi.to;
            amounts[i] = wi.amount;
            i++;
            (pair, wi) = peekQueue(staker);
            console.log("PEEKED", wi.opensAt, block.timestamp);
        }
    }

    bytes32 constant SLASH_STAKE =
        keccak256("SlashStake(address user,uint256 amount)");
    /**
     * @notice Slashes a user stake. First, all pending withdrawals are cancelled.
     * This is to ensure withdrawers are also penalized at the same rate.
     */
    function slashUser(
        address user,
        uint256 amount,
        uint64 expiry,
        bytes32 salt,
        bytes memory multiSignature
    ) external returns (uint256) {
        bytes32 message = keccak256(abi.encode(SLASH_STAKE, user, amount));
        auth.validateAuthoritySignature(IQuantumPortalAuthorityMgr.Action.SLASH, message, salt, expiry, multiSignature);
        amount = cancelWithdrawals(user);
        return slashStake(user, amount);
    }

    function slashStake(
        address staker,
        uint256 amount
    ) internal returns (uint256 remaining) {
		uint stake = state.stakes[STAKE_ID][staker];
        stake = amount < stake ? amount : stake;
        remaining = amount - stake;
        _withdrawOnlyUpdateStateAndPayRewards(slashTarget, STAKE_ID, staker, stake);
        address token = baseInfo.baseToken[STAKE_ID];
        sendToken(token, slashTarget, amount);
    }

    /**
     * @notice Go through all the pending withdrawals for the user. Delete them and
     * stake them back.
     * @param staker staker address
     */
    function cancelWithdrawals(
        address staker
    ) internal returns (uint256 total) {
        Pair memory param = withdrawItemsQueueParam[staker];
        for (uint i=param.start; i<param.end; i++) {
            WithdrawItem memory wi = withdrawItemsQueue[staker][i];
            delete withdrawItemsQueue[staker][i];
            _stakeUpdateStateOnly(staker, STAKE_ID, wi.amount);
            total += wi.amount;
        }
        delete withdrawItemsQueueParam[staker];
    }

    function pushToQueue(address staker, WithdrawItem memory wi) private {
        uint end = withdrawItemsQueueParam[staker].end;
        withdrawItemsQueueParam[staker].end = uint64(end) + 1;
        withdrawItemsQueue[staker][end] = wi; // starts from 0, so end is empty by now
    }

    function popFromQueue(address staker, Pair memory pair) private {
        withdrawItemsQueueParam[staker].start = pair.start + 1;
        delete withdrawItemsQueue[staker][pair.start];
    }

    function peekQueue(address staker) private view returns (Pair memory pair, WithdrawItem memory wi) {
        pair = withdrawItemsQueueParam[staker];
        wi = withdrawItemsQueue[staker][pair.start];
    }
}