// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IBridgeRoutingTable {
    struct TokenWithdrawConfig {
        address targetToken;
        uint64 feeX10000;
        uint16 groupId;
        uint8 noFee;
    }

    function withdrawConfig(address token)
        external
        view
        returns (TokenWithdrawConfig memory config);

    function verifyRoute(
        address sourceToken,
        uint256 targetChainId,
        address targetToken
    ) external view;
}
