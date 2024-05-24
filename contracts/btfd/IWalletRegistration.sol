pragma solidity 0.8.25;

interface IWalletRegistration {
    function walletForProxy(address proxy) external view returns (address);
}
