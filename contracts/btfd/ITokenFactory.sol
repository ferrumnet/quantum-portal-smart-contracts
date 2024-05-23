pragma solidity 0.8.25;

interface ITokenFactory {
    function registration() external view returns (address);
    function qpWallet() external view returns (address);
    function btc() external view returns (address);
    function portal() external view returns (address);
}