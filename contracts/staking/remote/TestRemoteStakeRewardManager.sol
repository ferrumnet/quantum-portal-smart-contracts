// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;
import "./RemoteStakeRewardManager.sol";

/**
 A dummy implementation of RemoteStakeRewardManager
 */
contract TestRemoteStakeRewardManager is RemoteStakeRewardManager {
    mapping(address=>mapping(address=>uint256)) _stakes;
    function getStake(
        address source,
        address to,
        address token
    ) internal view override returns (uint256) {
        return _stakes[token][to];
    }
    function setStake(address to, address id, uint256 amount) external {
        _stakes[id][to] = amount;
    }
}