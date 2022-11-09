// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../../common/TokenReceivable.sol";

contract QuantumPortalFeeManager is TokenReceivable {
    /**
     @notice Makes sure the msg.sender is the portal
     */
    modifier onlyPortal() {
        _;
    }

    /**
     @notice Charges the provided amount of fees from the caller.
     */
    function chargeFee(address caller, uint256 amount) external onlyPortal {
        // Charges the fee from the users balance
    }

    /**
     @notice Deposits fee for the caller
     */
    function depositFee(address caller) external {}

    /**
     @notice Takes back deposited fees
     */
    function withdrawFees() external {}
}
