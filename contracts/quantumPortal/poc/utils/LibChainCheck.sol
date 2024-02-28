// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibChainCheck {
    function isFerrumChain() internal view returns (bool) {
        return block.chainid == 26100 || block.chainid == 26000;
    }
}