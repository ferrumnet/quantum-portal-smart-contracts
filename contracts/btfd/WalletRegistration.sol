pragma solidity ^0.8.24;

import "./IWalletRegistration.sol";
import "./BtcLib.sol";

error NotValidTx();

contract WalletRegistration is IWalletRegistration {
    mapping (address => address) public override walletForProxy;

    function registerProxyFromBtcTx(bytes32 txid) external {
        // btcSender is the BTC address, proxy is the evm address that can act on its behalf
        (address btcSender, address proxy) = BtcLib.extractSenderAndProxyFromTx(txid);
        if (btcSender == address(0) || proxy == address(0)) revert NotValidTx();
        walletForProxy[btcSender] = proxy;
    }

    function unregisterProxy() external {
        // Proxy does not represent a wallet any more
        delete walletForProxy[msg.sender];
    }
}