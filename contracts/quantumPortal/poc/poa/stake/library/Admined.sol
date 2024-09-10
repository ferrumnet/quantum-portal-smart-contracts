// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./StakingBasics.sol";

abstract contract Admined is Ownable {
  mapping (address => mapping(address => StakingBasics.AdminRole)) public admins;

  function setAdmin(address id, address admin, StakingBasics.AdminRole role) onlyOwner external {
    admins[id][admin] = role;
  }
}
