// SPDX-License-Identifier: MIT
pragma solidity ~0.8.2;

import "../MultiSigCheckable.sol";

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
contract TestMultiSigCheckable is MultiSigCheckable {
	constructor () EIP712("TEST_MULTI_SIG_CHECKABLE", "1.0.0") {
	}
}