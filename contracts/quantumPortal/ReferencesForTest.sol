// SPDX-License-Identifier: MIT

/**
 * This file is to allow refencing the imported contracts, in the test code, because it will trigger
 * hardhat to create the relavant artifacts.
 */

pragma solidity ^0.8.0;

import "foundry-contracts/contracts/common/FerrumDeployer.sol";
import "foundry-contracts/contracts/dummy/DummyToken.sol";
import "foundry-contracts/contracts/token/MiniErc20Direct.sol";

contract DummyToken_ is DummyToken {}

contract DirectMinimalErc20_ is DirectMinimalErc20 {}

contract FerrumDeployer_ is FerrumDeployer {}
