// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../quantumPortal/poc/utils//WithQp.sol";
import "../quantumPortal/poc/utils/WithRemotePeers.sol";


contract Ping is WithQp, WithRemotePeers {

    uint256 public numbPingsSent;
    uint256 public numbPingsReceived;
    uint256 public feeAmount;

    event Ping(uint256 numbPingsSent);
    event ReceivePing(uint256 numbPingsReceived);

    error NotRemotePeer();
    
    constructor(
        address _portal,
        uint256 _feeAmount
    ) Ownable(tx.origin) {
        _initializeWithQp(_portal);
        feeAmount = _feeAmount;
    }
    
    function ping(uint256 chainId) external payable {
        if (msg.value == 0) {
            IERC20(portal.feeToken()).transfer(portal.feeTarget(), feeAmount);
        } else {
            portal.runWithValueNativeFee{value: msg.value}(
                uint64(chainId),
                remotePeers[chainId],
                owner(),
                portal.feeToken(),
                abi.encodePacked(this.receivePing.selector)
            );
        }

        numbPingsSent++;

        emit Ping(numbPingsSent);
    }

    function receivePing() external {
        (uint256 sourceChainId, address sourceRouter,) = portal.msgSender();
        if (remotePeers[sourceChainId] != sourceRouter) revert NotRemotePeer();

        numbPingsReceived++;

        emit ReceivePing(numbPingsReceived);
    }

    function updateFeeAmount(uint256 _feeAmount) external onlyOwner {
        feeAmount = _feeAmount;
    }
}
