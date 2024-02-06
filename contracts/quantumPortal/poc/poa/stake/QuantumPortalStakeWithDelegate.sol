// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IQuantumPortalStakeWithDelegate.sol";
import "../QuantumPortalAuthorityMgr.sol";
import "../Delegator.sol";
import "./WorkerInvestor.sol";
import "../../../../staking/StakeOpen.sol";

import "hardhat/console.sol";

/**
 @notice The QP stake with delegate is designed for stakers to stake, and
    delegate to an actor ID (miner/validator). There are a few key concepts
    here:
    1 - Unstake will move assets to a locked state, for a period.
    2 - Authorities can slash.
    3 - Slash will be applied to a whole group of stakers that delegated to an address.
    4 - Once someone is slashed, the group cannot stake any more.
 */
contract QuantumPortalStakeWithDelegate is StakeOpen, WorkerInvestor, IQuantumPortalStakeWithDelegate {
    struct WithdrawItem {
        uint64 opensAt;
        uint128 amount;
        address to;
    }

    struct Pair {
        uint64 start;
        uint64 end;
    }

    uint64 constant WITHDRAW_LOCK = 30 days;
    bytes32 constant SLASH_STAKE =
        keccak256("SlashStake(address user,uint256 amount, bytes32 salt, uint64 expiry)");
    address public override STAKE_ID;
    address public gateway;
    address public slashTarget;
    IQuantumPortalAuthorityMgr public auth;
    mapping(address => Pair) public withdrawItemsQueueParam;
    mapping(address => mapping(uint => WithdrawItem)) public withdrawItemsQueue;
    mapping(address => uint256) public investorStake; // Total stake accumulated for an investor, INCLUDING the withdraw queue
    mapping(address => uint256) public investorSlash; // Total slash for an investor
    // Delegations of stakers to an investor. We limit user to delegate to only one investor from one address
    // to delegate to a different investor, stakers will need to use a different address
    mapping(address => address) public override investorDelegations; 

    constructor() {
        bytes memory _data = IFerrumDeployer(msg.sender).initData();
        (address token, address authority, address _gateway) = abi.decode(
            _data,
            (address, address, address)
        );
        address[] memory tokens = new address[](1);
        tokens[0] = token;
        _init(token, "QP Stake", tokens);
        STAKE_ID = token;
        auth = IQuantumPortalAuthorityMgr(authority);
        gateway = _gateway;
    }

    /**
     * @inheritdoc IQuantumPortalStakeWithDelegate
     */
    function stakeOfInvestor(
        address worker
    ) external view override returns (uint256) {
        require(worker != address(0), "QPS: worker required");
        IWorkerInvestor.Relationship memory rd = investorLookup[worker];
        if (rd.deleted == 1) {
            return 0;
        }
        address investor = rd.investor;
        require(investor != address(0), "QPS: investor not valid");
        return investorStake[investor]; // Total amount staked for an investor from delegators
    }

    /**
     * @inheritdoc IQuantumPortalStakeWithDelegate
     */
    function setInvestorDelegations(
        address investor,
        address staker
    ) external override {
        // Can only be called by the staker or the gateway. Gateway in part ensures being called by the staker
        require(msg.sender == staker || msg.sender == gateway, "QPS: unauthorized");
        address currentDelegation = investorDelegations[staker];
        if (currentDelegation == address(0)) {
            investorDelegations[staker] = investor;
        } else {
            require(currentDelegation == investor, "QPS: delegation not allowed");
        }
    }

    /**
     * @notice Only staker can release WI. This is to allow staker to be a smart contract
     * and manage state when withdraw happens.
     * @param staker The staker.
     * @return paidTo Returns the list of payments.
     * @return amounts Returns the list of payments.
     */
    function releaseWithdrawItems(
        address staker
    ) external returns (address[] memory paidTo, uint256[] memory amounts) {
        require(staker != address(0), "QPS: staker requried");
        require(msg.sender == staker, "QPS: not owner");
        address token = baseInfo.baseToken[STAKE_ID];
        (Pair memory pair, WithdrawItem memory wi) = peekQueue(staker);
        paidTo = new address[](pair.end - pair.start);
        amounts = new uint256[](pair.end - pair.start);
        console.log("PEEKED", wi.opensAt, block.timestamp);
        uint i = 0;

        // Identify slash ratio
        address investor = investorDelegations[staker];
        uint256 slashAmount = investorSlash[investor];
        uint256 slashRatio = FullMath.mulDiv(slashAmount, FixedPoint128.Q128, investorStake[investor]);

        while (wi.opensAt != 0 && wi.opensAt < block.timestamp) {
            popFromQueue(staker, pair);

            // First remove the slashed amount from the withdrawal
            // This algorithm works because after slash, staking will be closed for the address
            uint256 slashed = slashAmount == 0 ? 0 :
                FullMath.mulDiv(slashRatio, wi.amount, FixedPoint128.Q128);
            console.log("Sending tokens slash", slashed, wi.amount);
            uint256 payAmount = wi.amount > slashed ? wi.amount - slashed : 0;
            investorSlash[investor] = investorSlash[investor] - slashed;
            investorStake[investor] = investorStake[investor] - wi.amount;
            paidTo[i] = wi.to;
            amounts[i] = payAmount;
            i++;
            if (payAmount != 0) {
                sendToken(token, wi.to, payAmount);
            }
            (pair, wi) = peekQueue(staker);
            console.log("PEEKED", wi.opensAt, block.timestamp);
        }
    }

    /**
     * @notice Slashes a user stake. First, all pending withdrawals are cancelled.
     * This is to ensure withdrawers are also penalized at the same rate.
     * @param investor The investor to be slashed
     * @param amount The amount of slash
     * @param salt A unique salt
     * @param expiry Signature expiry
     * @param multiSignature The signatrue
     */
    function slashInvestor(
        address investor,
        uint256 amount,
        bytes32 salt,
        uint64 expiry,
        bytes memory multiSignature
    ) external returns (uint256) {
        bytes32 message = keccak256(abi.encode(SLASH_STAKE, investor, amount, salt, expiry));
        auth.validateAuthoritySignature(
            IQuantumPortalAuthorityMgr.Action.SLASH,
            message,
            salt,
            expiry,
            multiSignature
        );
        uint256 totalSlash = investorSlash[investor] + amount;
        require(totalSlash <= investorStake[investor], "QPSWD: not enough stake");
        investorSlash[investor] = totalSlash;
        // Transfer the funds already slashed
        address token = baseInfo.baseToken[STAKE_ID];
        sendToken(token, slashTarget, amount);
        return totalSlash;
    }

    function stakeToInvestor(address to, address investor
    ) external {
        address currentInvstor = investorDelegations[to];
        if (currentInvstor == address(0)) {
            investorDelegations[to] = investor;
        } else {
            require(currentInvstor == investor, "QPS: invalid investor");
        }

        _stake(to, STAKE_ID, 0);
    }

    function _stake(
        address to,
        address id,
        uint256 allocation
    ) internal override returns (uint256) {
        address investor = investorDelegations[to];
        require(investor != address(0), "QPS: no investor assigned");
        require(investorSlash[investor] == 0, "QPS: investor is slashed");
        uint256 amount = StakeOpen._stake(to, id, allocation);
        investorStake[investor] = investorStake[investor] + amount;
        return amount;
    }

    /**
     * @notice This will only move items to the withdraw queue.
     * For slashed stakes, the withdraw will go as normal. We only apply the gg ratio
     * on the release.
     * @param to Receiver of the funds
     * @param id The stake ID
     * @param staker The staker
     * @param amount The withdraw amount
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
     * @notice Pushes a withdraw item to the queue
     * @param staker The staker
     * @param wi The withdraw item
     */
    function pushToQueue(address staker, WithdrawItem memory wi) private {
        uint end = withdrawItemsQueueParam[staker].end;
        withdrawItemsQueueParam[staker].end = uint64(end) + 1;
        withdrawItemsQueue[staker][end] = wi; // starts from 0, so end is empty by now
    }

    /**
     * @notice Pops a withdraw item from the queue
     * @param staker The staker
     * @param pair The withdraw item pair
     */
    function popFromQueue(address staker, Pair memory pair) private {
        withdrawItemsQueueParam[staker].start = pair.start + 1;
        delete withdrawItemsQueue[staker][pair.start];
    }

    /**
     * @notice Pools the queue for the withdraw item
     * @param staker The staker
     * @return pair The current pair
     * @return wi The current withdraw item
     */
    function peekQueue(
        address staker
    ) private view returns (Pair memory pair, WithdrawItem memory wi) {
        pair = withdrawItemsQueueParam[staker];
        wi = withdrawItemsQueue[staker][pair.start];
    }
}

