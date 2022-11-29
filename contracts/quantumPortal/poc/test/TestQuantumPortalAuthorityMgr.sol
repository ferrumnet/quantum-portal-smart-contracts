// SPDX-License-Identifier: MIT
pragma solidity ~0.8.2;

import "../../poc/poa/QuantumPortalAuthorityMgr.sol";

/**
 @notice
    Base class for contracts handling multisig transactions
      Rules:
      - First set up the master governance quorum (groupId 1). onlyOwner
	  - Owner can remove public or custom quorums, but cannot remove governance
	  quorums.
	  - Once master governance is setup, governance can add / remove any quorums
	  - All actions can only be submitted to chain by admin or owner
 */
contract TestQuantumPortalAuthorityMgr is QuantumPortalAuthorityMgr {
     
    constructor()  {}
}
