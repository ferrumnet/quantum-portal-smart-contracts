// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./NoDelegateCall.sol";
import "../interfaces/IStakeInfo.sol";
import "./IStakingTokenDeployer.sol";

// TODO: Implement "burn"...
// Burn should also burn the underlying token
contract StakingTokenPool is IERC20 {
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);

    address public immutable factory;
    address public immutable stakingPoolAddress;
    address public /*immutable*/ stakingPoolId; // To keep etherscan verif happy :(
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    // mapping(address => mapping(address => uint)) public override allowance;

    constructor() {
        address spa;
        address spi;
        (factory,
            spa,
            spi,
            name,
            symbol) = IStakingTokenDeployer(msg.sender).parameters();
        
        stakingPoolAddress = spa;
        stakingPoolId = spi;
        require(IStakeInfo(spa).isTokenizable(spi), "STP: pool is not tokenizable");
    }

    function totalSupply() public view override returns (uint256) {
        return IStakeInfo(stakingPoolAddress).stakedBalance(stakingPoolId);
    }

		function allowance(address owner, address spender)
		external override view returns (uint256) {
    	return IStakeTransferrer(stakingPoolAddress).
				allowance(stakingPoolId, owner, spender); 
		}

    function balanceOf(address staker) external override view returns (uint256) {
        return IStakeInfo(stakingPoolAddress).stakeOf(stakingPoolId, staker);
    }

    function approve(address spender, uint value) external override returns (bool) {
        require(IStakeTransferrer(stakingPoolAddress)
					.approveOnlyPool(stakingPoolId, msg.sender, spender, value), "STP: approve failed");
				emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) external override returns (bool) {
        IStakeTransferrer(stakingPoolAddress)
					.transferOnlyPool(stakingPoolId, msg.sender, to, value);
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value)
		external override returns (bool) {
        return IStakeTransferrer(stakingPoolAddress)
					.transferFromOnlyPool(stakingPoolId, msg.sender, from, to, value);
    }
}