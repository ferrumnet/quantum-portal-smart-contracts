// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../quantumPortal/poc/utils/WithQp.sol";
import "../quantumPortal/poc/utils/WithRemotePeers.sol";
import "./ClientPing.sol";


contract ServerPong is WithQp, WithRemotePeers {
    
    uint256 public feeAmount;
    mapping (uint256 => uint256) public numbPongs;

    error NotClient();

    event Pong(uint256 sourceChainId, uint256 numbPongs);

    modifier onlyPortal() {
        require(msg.sender == address(portal), "Only portal");
        _;
    }

    constructor(address _portal, uint256 _feeAmount) Ownable(msg.sender) {
        _initializeWithQp(_portal);
        feeAmount = _feeAmount;
    }

    function pong() external onlyPortal {
        (uint256 sourceChainId, address sourceRouter,) = portal.msgSender();
        if (remotePeers[sourceChainId] != sourceRouter) revert NotClient(); // Ensure the sender is a client

        numbPongs[sourceChainId]++;

        if (feeAmount > 0) {
            IERC20(portal.feeToken()).transfer(portal.feeTarget(), feeAmount);
        }
        
        portal.run(
            uint64(sourceChainId),
            sourceRouter,
            owner(),
            abi.encodePacked(ClientPing.receivePongResponse.selector)
        );

        emit Pong(sourceChainId, numbPongs[sourceChainId]);
    }

    function updateFeeAmount(uint256 _feeAmount) external onlyOwner {
        feeAmount = _feeAmount;
    }
}
