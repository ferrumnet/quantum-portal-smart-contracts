// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./NoDelegateCall.sol";
import "./IStakingTokenDeployer.sol";
import "./StakingTokenPool.sol";

abstract contract StakingTokenDeployer is IStakingTokenDeployer {
    struct Parameters {
        address factory;
        address stakingPoolAddress;
        address stakingPoolId;
        string name;
        string symbol;
    }

    Parameters public override parameters;

    function deploy(
        address factory,
        address stakingPoolAddress,
        address stakingPoolId,
        string memory name,
        string memory symbol
    ) internal returns (address pool) {
        parameters = Parameters({
            factory: factory,
            stakingPoolAddress: stakingPoolAddress,
            stakingPoolId: stakingPoolId,
            name: name,
            symbol: symbol});

        pool = address(new StakingTokenPool{salt: keccak256(
            abi.encode(stakingPoolAddress, stakingPoolId))}());
        delete parameters;
    }
}