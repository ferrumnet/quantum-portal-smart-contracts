// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./StakingTokenDeployer.sol";
import "./IStakingFactory.sol";
import "./NoDelegateCall.sol";
import "../interfaces/IStakeV2.sol";
import "../interfaces/IStakeInfo.sol";

contract StakingFactoryV2 is StakingTokenDeployer, NoDelegateCall, IStakingFactory {
    mapping(address => mapping(address => address)) public override getPool;

    function createPool(
        address stakingPoolAddress,
        address stakingPoolId,
        string memory symbol
    ) external override noDelegateCall returns (address pool) {
	    string memory name = IStakeV2(stakingPoolAddress).name(stakingPoolId);
	    require(bytes(name).length != 0, "SFV2: Staking not found");
	    require(bytes(symbol).length != 0, "SFV2: Symbol is required");
        require(IStakeInfo(stakingPoolAddress).isTokenizable(stakingPoolId), "SFV2: Pool not tokenizable");
        pool = deploy(address(this), stakingPoolAddress, stakingPoolId, name, symbol);
        getPool[stakingPoolAddress][stakingPoolId] = pool;
        emit PoolCreated(stakingPoolAddress, stakingPoolId, symbol, pool);
    }
}