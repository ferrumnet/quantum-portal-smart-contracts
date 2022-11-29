// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../IQuantumPortalPoc.sol";
import "../IQuantumPortalFeeManager.sol";
import "foundry-contracts/contracts/common/IFerrumDeployer.sol";
import "foundry-contracts/contracts/token/ERC20/ERC20.sol";
import "foundry-contracts/contracts/common/SafeAmount.sol";
import "foundry-contracts/contracts/math/FullMath.sol";
import "./MultiChainBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/*
  Multi-chain staking, allows users to stake a token from any chain. And take their rewards from a different chain.
  The staking state is stored on the master chain (i.e. Ferrum). Hence, the stake method will check
  if we are currently on the master chain, we will stake locally, otherwise, we will subvmite a remote stake
  request.
  For the withdraw, we generate two withdraws, one on the local (for reward), and one on the source chain.

  For simplicity, we have a staking period that is closed by owner. Then rewards can be claimed at maturity.
 */
contract MultiChainStakingMaster is MultiChainMasterBase {
    // Staking related state
    mapping (uint256 => address) public baseTokens; // Token address for each chain
    mapping (uint256 => mapping (address => uint256)) public stakes; // User address (chin+addr) => stake
    address rewardToken;
    uint256 public totalRewards; // Total rewards
    uint256 public totalStakes; // Total stakes
    bool public stakeClosed; // A flag to set when the staking is closed. Set this only on master chain
    bool public distributeRewards; // A flag to set when we are ready to distribute rewards. Only on master chain

    function closeStakePeriod() external onlyOwner {
        stakeClosed = true;
    }

    function enableRewardDistribution() external onlyOwner {
        distributeRewards = true;
    }

    function setRewardToken(address _rewardToken) external onlyOwner {
        rewardToken = _rewardToken;
    }

    function init(
        uint256[] calldata remoteChainIds,
        address[] calldata stakingContracts,
        address[] calldata _baseTokens
    ) onlyOwner external{
        for (uint i=0; i < remoteChainIds.length; i++) {
            remotes[remoteChainIds[i]] = stakingContracts[i];
            baseTokens[remoteChainIds[i]] = _baseTokens[i];
        }
    }

    /**
     @notice UI should check the master chain to make sure staking period is open. Otherwise the x-chain transaction will fail.
     */
    function stake(uint256 amount) external nonReentrant {
        amount = SafeAmount.safeTransferFrom(baseTokens[CHAIN_ID], msg.sender, address(this), amount);
        require(amount != 0, "No stake");
        doStake(CHAIN_ID, msg.sender, amount);
    }

    /**
     @notice To be called by QP
     */
    function stakeRemote() external {
        (uint netId, address sourceMsgSender, address beneficiary) = portal.msgSender();
        require(sourceMsgSender == remotes[netId], "Not allowed");
        QuantumPortalLib.RemoteTransaction memory _tx = portal.txContext().transaction;
        require(_tx.token == baseTokens[netId], "Unexpected token");
        doStake(netId, beneficiary, _tx.amount);
    }

    function doStake(uint256 chainId, address staker, uint256 amount) internal {
        require(!stakeClosed && !distributeRewards, "Stake closed");
        stakes[chainId][staker] += amount;
        totalStakes += amount;
    }
    
    function addRewards(uint256 amount) external nonReentrant {
        require(!distributeRewards, "Already distributed/(ing) rewards");
        amount = SafeAmount.safeTransferFrom(rewardToken, msg.sender, address(this), amount);
        require(amount != 0, "No rewards");
        totalRewards += amount;
    }

    /**
     @notice For simplicity, we assume user has same address for all chains
     */
    function closePosition(uint256 fee, uint256 chainId) external {
        require(distributeRewards, "Not ready to distribute rewards");
        if (chainId == CHAIN_ID) {
            closePositionLocal();
        } else {
            closePositionRemote(fee, chainId);
        }
    }

    function remoteAddress(uint256 chainId) public view returns(address rv) {
        rv = remotes[chainId];
        rv = rv == address(0) ? address(this) : rv;
    }

    function closePositionLocal() internal {
        uint256 staked = stakes[CHAIN_ID][msg.sender];
        uint256 reward = calcReward(staked);
        stakes[CHAIN_ID][msg.sender] = 0;
        // Transfer base
        IERC20(baseTokens[CHAIN_ID]).transfer(msg.sender, staked);
        // Transfer rewards
        IERC20(rewardToken).transfer(msg.sender, reward);
     }

    function closePositionRemote(uint256 fee, uint256 chainId) internal {
        uint256 staked = stakes[chainId][msg.sender];
        uint256 reward = calcReward(staked);
        stakes[chainId][msg.sender] = 0;
        // Transfer rewards
        IERC20(rewardToken).transfer(msg.sender, reward);
        // This should initiate a withdaw on the remote side...
        portal.runWithdraw(
            fee, uint64(chainId), msg.sender, baseTokens[chainId], staked);
    }

    function calcReward(uint256 stakeAmount) private view returns (uint256) {
        return FullMath.mulDiv(stakeAmount, totalRewards, totalStakes);
    }
}

contract MultiChainStakingClient is MultiChainClientBase {
    /**
     @notice It is up to UI to make sure the token is correct. Otherwise the tx will fail.
     */
    function stake(address token, uint256 amount, uint256 fee) external {
        require(SafeAmount.safeTransferFrom(token, msg.sender, address(portal), amount) != 0, "Nothing transferred");
        bytes memory method = abi.encodeWithSelector(MultiChainStakingMaster.stakeRemote.selector);
        portal.runWithValue(
            fee, uint64(MASTER_CHAIN_ID), masterContract, msg.sender, token, method);
    }
}