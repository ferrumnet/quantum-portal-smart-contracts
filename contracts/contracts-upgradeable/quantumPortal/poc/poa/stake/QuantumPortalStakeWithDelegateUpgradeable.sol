// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Initializable, UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {FullMath} from "foundry-contracts/contracts/contracts/math/FullMath.sol";
import {FixedPoint128} from "foundry-contracts/contracts/contracts/math/FixedPoint128.sol";
import {IQuantumPortalStakeWithDelegate} from "../../../../../quantumPortal/poc/poa/stake/IQuantumPortalStakeWithDelegate.sol";
import {IQuantumPortalAuthorityMgr, QuantumPortalAuthorityMgrUpgradeable} from "../QuantumPortalAuthorityMgrUpgradeable.sol";
import {IOperatorRelation, OperatorRelationUpgradeable} from "./OperatorRelationUpgradeable.sol";
import {StakeOpenUpgradeable} from "../../../../staking/StakeOpenUpgradeable.sol";


/**
 @notice The QP stake with delegate is designed for stakers to stake, and
    delegate to an actor ID (miner/validator). There are a few key concepts
    here:
    1 - Unstake will move assets to a locked state, for a period.
    2 - Authorities can slash.
    3 - Slash will be applied to a whole group of stakers that delegated to an address.
    4 - Once someone is slashed, the group cannot stake any more.
 */
contract QuantumPortalStakeWithDelegateUpgradeable is
    Initializable,
    UUPSUpgradeable,
    StakeOpenUpgradeable,
    OperatorRelationUpgradeable,
    IQuantumPortalStakeWithDelegate
{
    uint64 constant WITHDRAW_LOCK = 30 days;
    bytes32 constant SLASH_STAKE = keccak256("SlashStake(address user,uint256 amount, bytes32 salt, uint64 expiry)");
    bytes32 constant ALLOW_STAKE = keccak256("AllowStake(address to,address delegate,uint256 allocation, bytes32 salt, uint64 expiry)");

    /// @custom:storage-location erc7201:ferrum.storage.quantumportalstakewithdelegate.001
    struct QuantumPortalStakeWithDelegateStorageV001 {
        address STAKE_ID;
        address slashTarget;
        IQuantumPortalAuthorityMgr auth;
        IQuantumPortalAuthorityMgr stakeVerifyer;
        mapping(address => Pair) withdrawItemsQueueParam;
        mapping(address => mapping(uint => WithdrawItem)) withdrawItemsQueue;
        mapping(address => uint256) delegateStake; // Total stake accumulated for an delegate, INCLUDING the withdraw queue
        mapping(address => uint256) delegateSlash; // Total slash for a delegate
        // Delegations of stakers to an delegate. We limit user to delegate to only one delegate from one address
        // to delegate to a different delegate, stakers will need to use a different address
        mapping(address => address) delegations;
    }

    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.quantumportalstakewithdelegate.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant QuantumPortalStakeWithDelegateStorageV001Location = 0x9e96bf63ee42375e48d4b671645d4db3f0238a955b3df5ce6faf0b053878b200;

    struct WithdrawItem {
        uint64 opensAt;
        uint128 amount;
        address to;
    }

    struct Pair {
        uint64 start;
        uint64 end;
    }

    function initialize(
        address _token,
        address _authority,
        address _stakeVerifyer,
        address _gateway,
        address initialOwnerAdmin
    ) public initializer {
        __Ownable_init(initialOwnerAdmin);
        __WithGateway_init_unchained(_gateway);
        __BaseStakingV2_init();

        address[] memory tokens = new address[](1);
        tokens[0] = _token;
        _init(_token, "QP Stake", tokens);

        QuantumPortalStakeWithDelegateStorageV001 storage $ = _getQuantumPortalStakeWithDelegateStorageV001();
        $.STAKE_ID = _token;
        $.auth = IQuantumPortalAuthorityMgr(_authority);
        $.stakeVerifyer = IQuantumPortalAuthorityMgr(_stakeVerifyer);
    }

    function STAKE_ID() external view returns (address) {
        QuantumPortalStakeWithDelegateStorageV001 storage $ = _getQuantumPortalStakeWithDelegateStorageV001();
        return $.STAKE_ID;
    }

    function slashTarget() external view returns (address) {
        QuantumPortalStakeWithDelegateStorageV001 storage $ = _getQuantumPortalStakeWithDelegateStorageV001();
        return $.slashTarget;
    }

    function auth() external view returns (IQuantumPortalAuthorityMgr) {
        QuantumPortalStakeWithDelegateStorageV001 storage $ = _getQuantumPortalStakeWithDelegateStorageV001();
        return $.auth;
    }

    function stakeVerifyer() external view returns (IQuantumPortalAuthorityMgr) {
        QuantumPortalStakeWithDelegateStorageV001 storage $ = _getQuantumPortalStakeWithDelegateStorageV001();
        return $.stakeVerifyer;
    }

    function withdrawItemsQueueParam(address staker) external view returns (Pair memory) {
        QuantumPortalStakeWithDelegateStorageV001 storage $ = _getQuantumPortalStakeWithDelegateStorageV001();
        return $.withdrawItemsQueueParam[staker];
    }

    function withdrawItemsQueue(address staker, uint index) external view returns (WithdrawItem memory) {
        QuantumPortalStakeWithDelegateStorageV001 storage $ = _getQuantumPortalStakeWithDelegateStorageV001();
        return $.withdrawItemsQueue[staker][index];
    }

    function delegateStake(address delegate) external view returns (uint256) {
        QuantumPortalStakeWithDelegateStorageV001 storage $ = _getQuantumPortalStakeWithDelegateStorageV001();
        return $.delegateStake[delegate];
    }

    function delegateSlash(address delegate) external view returns (uint256) {
        QuantumPortalStakeWithDelegateStorageV001 storage $ = _getQuantumPortalStakeWithDelegateStorageV001();
        return $.delegateSlash[delegate];
    }

    function delegations(address staker) external view returns (address) {
        QuantumPortalStakeWithDelegateStorageV001 storage $ = _getQuantumPortalStakeWithDelegateStorageV001();
        return $.delegations[staker];
    }

    /**
     * @notice Updatesth te stake verifyer
     * @param newStakeVerifyer The new stake verifyer
     */
    function updateStakeVerifyer(address newStakeVerifyer) external onlyOwner {
        QuantumPortalStakeWithDelegateStorageV001 storage $ = _getQuantumPortalStakeWithDelegateStorageV001();
        $.stakeVerifyer = IQuantumPortalAuthorityMgr(newStakeVerifyer);
    }

    /**
     * @inheritdoc IQuantumPortalStakeWithDelegate
     */
    function stakeOfDelegate(
        address operator
    ) external view override returns (uint256) {
        QuantumPortalStakeWithDelegateStorageV001 storage $ = _getQuantumPortalStakeWithDelegateStorageV001();
        require(operator != address(0), "QPS: operator required");
        IOperatorRelation.Relationship memory rd = delegateLookup(operator);
        if (rd.deleted == 1) {
            return 0;
        }
        address delegate = rd.delegate;
        require(delegate != address(0), "QPS: delegate not valid");
        return $.delegateStake[delegate]; // Total amount staked for a delegate
    }

    /**
     * @inheritdoc IQuantumPortalStakeWithDelegate
     */
    function setDelegation(
        address delegate,
        address delegator
    ) external override {
        // Can only be called by the staker or the gateway. Gateway in part ensures being called by the staker
        require(msg.sender == delegator || msg.sender == gateway(), "QPS: unauthorized");
        _setDelegation(delegate, delegator);
    }

    /**
     * @notice Only staker can release WI. This is to allow staker to be a smart contract
     * and manage state when withdraw happens.
     * @param staker The staker.
     */
    function releaseWithdrawItems(
        address staker
    ) external returns (address[] memory paidTo, uint256[] memory amounts) {
        QuantumPortalStakeWithDelegateStorageV001 storage $ = _getQuantumPortalStakeWithDelegateStorageV001();
        require(staker != address(0), "QPS: staker requried");
        require(msg.sender == staker, "QPS: not owner");
        BaseStakingV2StorageV001 storage $b = _getBaseStakingV2StorageV001();
        address token = $b.baseInfo.baseToken[$.STAKE_ID];
        (Pair memory pair, WithdrawItem memory wi) = peekQueue(staker);
        paidTo = new address[](pair.end - pair.start);
        amounts = new uint256[](pair.end - pair.start);
        uint i = 0;

        // Identify slash ratio
        address delegate = $.delegations[staker];
        uint256 slashAmount = $.delegateSlash[delegate];
        uint256 slashRatio = FullMath.mulDiv(slashAmount, FixedPoint128.Q128, $.delegateStake[delegate]);

        while (wi.opensAt != 0 && wi.opensAt < block.timestamp) {
            popFromQueue(staker, pair);

            // First remove the slashed amount from the withdrawal
            // This algorithm works because after slash, staking will be closed for the address
            uint256 slashed = slashAmount == 0 ? 0 :
                FullMath.mulDiv(slashRatio, wi.amount, FixedPoint128.Q128);
            uint256 payAmount = wi.amount > slashed ? wi.amount - slashed : 0;
            $.delegateSlash[delegate] -= slashed;
            $.delegateSlash[delegate] -= wi.amount;
            paidTo[i] = wi.to;
            amounts[i] = payAmount;
            i++;
            if (payAmount != 0) {
                sendToken(token, wi.to, payAmount);
            }
            (pair, wi) = peekQueue(staker);
        }
    }

    /**
     * @notice Slashes a user stake. First, all pending withdrawals are cancelled.
     * This is to ensure withdrawers are also penalized at the same rate.
     * @param delegate The delegate to be slashed
     * @param amount The amount of slash
     * @param salt A unique salt
     * @param expiry Signature expiry
     * @param multiSignature The signatrue
     */
    function slashDelegate(
        address delegate,
        uint256 amount,
        bytes32 salt,
        uint64 expiry,
        bytes memory multiSignature
    ) external returns (uint256) {
        QuantumPortalStakeWithDelegateStorageV001 storage $ = _getQuantumPortalStakeWithDelegateStorageV001();
        bytes32 message = keccak256(abi.encode(SLASH_STAKE, delegate, amount, salt, expiry));
        $.auth.validateAuthoritySignature(
            IQuantumPortalAuthorityMgr.Action.SLASH,
            message,
            salt,
            expiry,
            multiSignature
        );
        uint256 totalSlash = $.delegateSlash[delegate] + amount;
        require(totalSlash <= $.delegateSlash[delegate], "QPSWD: not enough stake");
        $.delegateSlash[delegate] = totalSlash;
        // Transfer the funds already slashed
        BaseStakingV2StorageV001 storage $b = _getBaseStakingV2StorageV001();
        address token = $b.baseInfo.baseToken[$.STAKE_ID];
        sendToken(token, $.slashTarget, amount);
        return totalSlash;
    }

    function stakeToDelegateWithAllocation(
        address to,
        address delegate,
        uint256 allocation,
        bytes32 salt,
        uint64 expiry,
        bytes memory multiSignature
    ) external override {
        QuantumPortalStakeWithDelegateStorageV001 storage $ = _getQuantumPortalStakeWithDelegateStorageV001();
        require(address($.stakeVerifyer) != address(0), "PQS: verifyer not set");
        bytes32 message = keccak256(abi.encode(ALLOW_STAKE, to, delegate, allocation, salt, expiry));
        $.stakeVerifyer.validateAuthoritySignature(
            IQuantumPortalAuthorityMgr.Action.ALLOW_ACTION,
            message,
            salt,
            expiry,
            multiSignature
        );
        address currentDelegate = $.delegations[to];
        if (currentDelegate == address(0)) {
            $.delegations[to] = delegate;
        } else {
            require(currentDelegate == delegate, "QPS: invalid delegate");
        }

        _stake(to, $.STAKE_ID, allocation);
    }

    function stakeToDelegate(address to, address delegate
    ) external {
        QuantumPortalStakeWithDelegateStorageV001 storage $ = _getQuantumPortalStakeWithDelegateStorageV001();
        address currentDelegate = $.delegations[to];
        if (currentDelegate == address(0)) {
            $.delegations[to] = delegate;
        } else {
            require(currentDelegate == delegate, "QPS: invalid delegate");
        }

        _stake(to, $.STAKE_ID, 0);
    }

    function _stake(
        address to,
        address id,
        uint256 allocation
    ) internal override returns (uint256) {
        QuantumPortalStakeWithDelegateStorageV001 storage $ = _getQuantumPortalStakeWithDelegateStorageV001();
        // If admin is set, we need signed allocation amount
        address delegate = $.delegations[to];
        require(delegate != address(0), "QPS: no delegate assigned");
        require($.delegateSlash[delegate] == 0, "QPS: delegate is slashed");
        uint256 amount = StakeOpenUpgradeable._stake(to, id, 0);
        require(address($.stakeVerifyer) == address(0) || allocation >= amount, "QPS: not enough allocation");
        $.delegateStake[delegate] = $.delegateStake[delegate] + amount;
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
        QuantumPortalStakeWithDelegateStorageV001 storage $ = _getQuantumPortalStakeWithDelegateStorageV001();
        require(id == $.STAKE_ID, "QPS: bad id");
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
     * @notice Sets the delegation
     */
    function _setDelegation(
        address delegate,
        address delegator
    ) private {
        QuantumPortalStakeWithDelegateStorageV001 storage $ = _getQuantumPortalStakeWithDelegateStorageV001();
        address currentDelegate = $.delegations[delegator];
        if (currentDelegate == address(0)) {
            $.delegations[delegator] = delegate;
        } else {
            require(currentDelegate == delegate, "QPS:re-del not allowed");
        }
    }

    /**
     * @notice Pushes a withdraw item to the queue
     * @param staker The staker
     * @param wi The withdraw item
     */
    function pushToQueue(address staker, WithdrawItem memory wi) private {
        QuantumPortalStakeWithDelegateStorageV001 storage $ = _getQuantumPortalStakeWithDelegateStorageV001();
        uint end = $.withdrawItemsQueueParam[staker].end;
        $.withdrawItemsQueueParam[staker].end = uint64(end) + 1;
        $.withdrawItemsQueue[staker][end] = wi; // starts from 0, so end is empty by now
    }

    /**
     * @notice Pops a withdraw item from the queue
     * @param staker The staker
     * @param pair The withdraw item pair
     */
    function popFromQueue(address staker, Pair memory pair) private {
        QuantumPortalStakeWithDelegateStorageV001 storage $ = _getQuantumPortalStakeWithDelegateStorageV001();
        $.withdrawItemsQueueParam[staker].start = pair.start + 1;
        delete $.withdrawItemsQueue[staker][pair.start];
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
        QuantumPortalStakeWithDelegateStorageV001 storage $ = _getQuantumPortalStakeWithDelegateStorageV001();
        pair = $.withdrawItemsQueueParam[staker];
        wi = $.withdrawItemsQueue[staker][pair.start];
    }

    function _getQuantumPortalStakeWithDelegateStorageV001() internal pure returns (QuantumPortalStakeWithDelegateStorageV001 storage $) {
        assembly {
            $.slot := QuantumPortalStakeWithDelegateStorageV001Location
        }
    }
}
