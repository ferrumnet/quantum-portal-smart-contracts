pragma solidity ^0.8.24;

interface IFeeStore {
    function swapBtcWithFee(bytes32 txId, uint btcAmount) external;
}