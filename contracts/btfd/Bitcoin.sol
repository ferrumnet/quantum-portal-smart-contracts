pragma solidity 0.8.25;

import "./QpErc20Token.sol";

contract Bitcoin is QpErc20Token {
    function initialize(
    ) external initializer {
        __QPERC20_init(0, 0, "Bitcoin", "BTC", 18, 0);
        __Context_init();
    }

    /**
     * @notice This will settle the BTC using QP to a given BTC address.
     */
    function settleTo(string calldata _btcAddress, uint256 amount, uint256 btcFee) external override {
        QpErc20Storage storage $ = _getQPERC20Storage();
        // Withdraw the qpBalance for the user
        uint bal = $.qpBalanceOf[msg.sender];
        if (bal < amount+btcFee) revert NoBalance();
        _burnQp(msg.sender, amount);
        _transferQp(msg.sender, IQuantumPortalPoc($.factory.portal()).feeTarget(), btcFee);
        BtcLib.initiateWithdrawal(_btcAddress, $.tokenId, $.version, btcFee);
        emit SettlementInitiated(msg.sender, _btcAddress, amount, btcFee);
    }
}