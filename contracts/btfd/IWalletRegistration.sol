pragma solidity ^0.8.24;

interface IWalletRegistration {
    function walletForProxy(address proxy) external view returns (address);
}
