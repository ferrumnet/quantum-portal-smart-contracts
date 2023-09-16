// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../IQuantumPortalPoc.sol";
import "hardhat/console.sol";

contract EstimateGasExample {
    IQuantumPortalPoc public portal;
    mapping(address => uint) dummy;
    mapping(uint => uint) dummy2;

    constructor(address _portal) {
        portal = IQuantumPortalPoc(_portal);
    }

    /**
     * @notice Run some code that can be used without POC
     */
    function noPoc() external {
        dummy[address(this)] += 1;
    }

    function getContextOpen() external {
        (uint netId, address sourceMsgSender, address beneficiary) = portal
            .msgSender();
        console.log("CALLED BY 1", netId, sourceMsgSender);
        console.log("CALLED BY 2", beneficiary);
        dummy[address(this)] += 1;
        number = 18;
    }

    function getContextLimit() external {
        (uint netId, address sourceMsgSender, address beneficiary) = portal
            .msgSender();
        console.log("CALLED BY 1", netId, sourceMsgSender);
        console.log("CALLED BY 2", beneficiary);
        require(sourceMsgSender != address(0), "No internal call");
        dummy[address(this)] += 1;
        number = 19;
    }

    function expensiveContextCall(uint len) external {
        (uint netId, address sourceMsgSender, address beneficiary) = portal
            .msgSender();
        console.log("CALLED BY 1", netId, sourceMsgSender);
        console.log("CALLED BY 2", beneficiary);
        for (uint i = 0; i < len; i++) {
            dummy2[i] = i;
        }
        number = 20;
    }

    uint public number = 0;

    function setNumber(uint value) external {
        number = value;
    }
}
