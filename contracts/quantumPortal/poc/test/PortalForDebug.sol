pragma solidity ^0.8.0;
import "../QuantumPortalPoc.sol";

contract PortalForDebug is QuantumPortalPoc {
    constructor() PortalLedger(0) Ownable(msg.sender) {}

   function setContextForDebug(QuantumPortalLib.Context memory _context) external {
    PortalLedger.context = _context;
   }

   function callRemoteMethodForDebug(
        uint256 remoteChainId,
        address localContract,
        bytes memory method,
        uint256 gas
   ) external {
        bool res = PortalLedger.callRemoteMethod(remoteChainId, localContract, method, gas);
   }

   function resetContextForDebug() external {
    PortalLedger.resetContext();
   }
}