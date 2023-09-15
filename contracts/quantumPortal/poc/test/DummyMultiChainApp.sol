// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../QuantumPortalPoc.sol";
import "../QuantumPortalLedgerMgr.sol";
import "foundry-contracts/contracts/common/SafeAmount.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "hardhat/console.sol";

interface IDummyMultiChainApp {
    function receiveCall() external;
}

/**
 * @notice Dummy contract for testing. Run any configuration
 *   Send tokens to each contract
 */
contract DummyMultiChainApp is IDummyMultiChainApp {
  using SafeERC20 for IERC20;
    QuantumPortalPoc public portal;
    QuantumPortalLedgerMgr public mgr;
    address public feeToken;
    constructor(address _portal, address _mgr, address _feeToken) {
        portal = QuantumPortalPoc(_portal);
        mgr = QuantumPortalLedgerMgr(_mgr);
        feeToken = _feeToken;
    }

    function callOnRemote(uint256 remoteChainId, address remoteContract, address beneficiary, address token, uint256 amount) external {
        bytes memory method = abi.encodeWithSelector(IDummyMultiChainApp.receiveCall.selector);
        // Pay fee...
        uint fixedFee = mgr.calculateFixedFee(remoteChainId, method.length);
        // This estimate fee will work becaue the remote contract code and local ones are identical. In real world scenarios
        // there is no way for the local contract to calculate the var tx fee. Only the offchain application can do this by
        // calling the estimateGasForRemoteTransaction method on the remote QP ledger manager.
        console.log("Estimating gas...");
        uint gasFrom = gasleft();
        portal.estimateGasForRemoteTransaction(
            remoteChainId,
            address(this),
            address(this), 
            beneficiary,
            method,
            token,
            amount);
        uint varFee = gasFrom - gasleft();
        console.log("Estimating gas... Done.");
        IERC20(feeToken).safeTransfer(portal.feeTarget(), fixedFee + varFee);
        console.log("Sent fee: ", fixedFee + varFee);

        // Send the value and run the remote tx...
        IERC20(token).safeTransfer(address(portal), amount);
        console.log("Sent amount: ", amount);
        portal.runWithValue(
            uint64(remoteChainId), remoteContract, beneficiary, token, method);
        console.log("Remote run...");
    }

    function receiveCall() external override {
        (uint netId, address sourceMsgSender, address beneficiary) = portal.msgSender();
        console.log("DummyMultiChainApp: Remote msg called", netId, sourceMsgSender, beneficiary);
    }
}