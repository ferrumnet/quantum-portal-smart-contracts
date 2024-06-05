pragma solidity ^0.8.24;

interface ITokenFactory {
    function registration() external view returns (address);
    function qpWallet() external view returns (address);
    function qpRuneWallet() external view returns (address);
    function btc() external view returns (address);
    function portal() external view returns (address);
    function feeConvertor() external view returns (address);
    function feeStore() external view returns (address);
    function feeStoreCollectFee(bytes32 txId) external returns (uint);
    function feeStoreSweepToken(address token, uint amount, address to) external;
}