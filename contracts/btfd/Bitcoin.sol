pragma solidity ^0.8.24;

import "./QpErc20Token.sol";
import "./IFeeStore.sol";

error FeeIsLessThanAmountSentToQp(uint amount, uint fee);

contract Bitcoin is QpErc20Token {
    uint constant SATOSHI_TO_NAKAMOTO_CONVERSION = 1 gwei;
    function initialize(
    ) external initializer {
        __QPERC20_init(0, 0, "Bitcoin", "BTC", 18, 0);
        __TokenReceivable_init();
        __Context_init();
    }

    /**
     * @notice Procecess the fee and updates the amount if necessary
     */
    function collectFeeForFutureUse(bytes32 txId, uint feeInBtc) internal returns (uint) {
        QpErc20Storage storage $ = _getQPERC20Storage();
        address feeStore = $.factory.feeStore();
        _mintQp(feeStore, feeInBtc);
        IFeeStore(feeStore).swapBtcWithFee(txId, feeInBtc);
    }

    /**
     * @notice Procecess the fee and updates the amount if necessary
     */
    function processFee(bytes32 txId, uint amount, uint feeInBtc) internal override returns (uint) {
        QpErc20Storage storage $ = _getQPERC20Storage();
        feeInBtc *= SATOSHI_TO_NAKAMOTO_CONVERSION; // Fee is in sats. We convert it to nakamoto
        if (amount < feeInBtc) {
            revert FeeIsLessThanAmountSentToQp(amount, feeInBtc);
        }
        collectFeeForFutureUse(txId, feeInBtc);
        $.factory.feeStoreCollectFee(txId); // Merge the two steps, where in case of rune, these two steps are managed in separate mining calls
        return amount - feeInBtc;
    }

    function preProcessValues(uint[] memory values) internal pure override returns (uint[] memory) {
        for (uint i=0; i<values.length; i++) {
            values[i] *= SATOSHI_TO_NAKAMOTO_CONVERSION;
        }
        return values;
    }

    function processRemoteCall(bytes32 txId, bytes memory remoteCall, uint amount) internal override {
        if (remoteCall.length == 0) {
            // Just collect the fee
            collectFeeForFutureUse(txId, amount);
        } else {
            QpErc20Token.processRemoteCall(txId, remoteCall, amount);
        }
    }

    /**
     * @notice Collects fee for BTC. Difference is that the fee can be taked without allowance
     */
    function collectSettlementFee(uint feeToCollect) internal override returns (uint) {
        if (feeToCollect != 0) {
            _transferQp(_msgSender(), address(this), feeToCollect);
        } 
        return sync(address(this));
    }
}