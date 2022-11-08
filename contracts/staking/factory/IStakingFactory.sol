// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStakingFactory {
    event PoolCreated(
        address indexed stakingPoolAddress,
        address indexed stakingPoolId,
        string indexed symbol,
        address pool
    );


    function getPool(address pool, address id) external view returns (address);

    function createPool(
        address stakingPoolAddress,
        address stakingPoolId,
        string memory symbol
    ) external returns (address);
}