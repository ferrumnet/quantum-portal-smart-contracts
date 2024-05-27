// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../../../quantumPortal/poc/utils/WithQp.sol";
import "hardhat/console.sol";
 
contract QpMultiSender is WithQp { 
  constructor(address _portal) Ownable(msg.sender) { 
    WithQp._initializeWithQp(_portal); 
  } 
 
  function qpMultiSend(address[] memory targets) external { 
   QuantumPortalLib.RemoteTransaction memory _tx = portal.txContext().transaction; 
   uint total = _tx.amount; 
   uint oneSend = total / targets.length;  
   console.log('total', total);
   console.log('oneSend', oneSend);
   console.log('token', _tx.token);
   for(uint i=0; i<targets.length; i++) { 
     console.log('SENDING TO', targets[i]);
     portal.localTransfer(_tx.token, targets[i], oneSend); 
   } 
  }  
} 