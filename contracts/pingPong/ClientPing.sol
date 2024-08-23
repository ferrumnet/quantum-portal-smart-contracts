// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../quantumPortal/poc/utils/WithQp.sol";
import "../quantumPortal/poc/utils/WithRemotePeers.sol";
import "./ServerPong.sol";


contract ClientPing is WithQp, WithRemotePeers {

    uint64 immutable serverChainId;
    address public serverAddress;
    uint256 public numbPingsSent;
    uint256 public numbPongsReceived;
    uint256 public feeAmount;

    event PingPong(uint256 numbPingsSent, uint256 numbPongsReceived);

    error NotServer();
    
    constructor(
        address _portal,
        uint64 _serverChainId,
        address _serverAddress,
        uint256 _feeAmount
    ) Ownable(tx.origin) {
        _initializeWithQp(_portal);
        serverChainId = _serverChainId;
        serverAddress = _serverAddress;
        feeAmount = _feeAmount;
        remotePeers[_serverChainId] = _serverAddress;
    }
    
    function ping() external {
        _ping();
    }

    function receivePongResponse() external {
        (uint256 sourceChainId, address sourceRouter,) = portal.msgSender();
        if (remotePeers[sourceChainId] != sourceRouter) revert NotServer();

        numbPongsReceived++;

        emit PingPong(numbPingsSent, numbPongsReceived);
    }

    function _ping() internal {
        if (feeAmount > 0) {
            IERC20(portal.feeToken()).transfer(portal.feeTarget(), feeAmount);
        }

        numbPingsSent++;

        portal.run(
            serverChainId,
            serverAddress,
            owner(),
            abi.encodePacked(ServerPong.pong.selector)
        );

        emit PingPong(numbPingsSent, numbPongsReceived);
    }

    function updateFeeAmount(uint256 _feeAmount) external onlyOwner {
        feeAmount = _feeAmount;
    }

    function updateServerAddress(address _serverAddress) external onlyOwner {
        serverAddress = _serverAddress;
        remotePeers[serverChainId] = _serverAddress;
    }
}
