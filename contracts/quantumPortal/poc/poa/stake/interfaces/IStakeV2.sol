// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Staking {
  enum StakeType { None, Unset, Timed, OpenEnded, PublicSale }
}

interface IStakeV2 {
  function stake(address to, address id) external returns (uint256);
  function stakeWithAllocation(
        address to,
        address id,
        uint256 allocation,
        bytes32 salt,
        bytes calldata allocatorSignature) external returns (uint256);
  function baseToken(address id) external returns(address);
  function name(address id) external returns (string memory);
}
