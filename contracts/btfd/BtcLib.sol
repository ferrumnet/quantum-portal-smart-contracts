pragma solidity ^0.8.24;

library BtcLib {
    struct TransferItem {
        address addr;
        uint value;
    }

    function parseBtcAddress(string calldata btcAddress) internal view returns (address) {
        // TODO: Call pre-compile
    }

    function initiateWithdrawal(string calldata btcAddress, uint tokenId, uint version, uint btcFee, bytes32 settlementId) internal {
        // TODO: Call pre-compile
        // Note. Pre-compile identifies who the caller is by verifying that msg.sender mapps to the token ID
        // For example, for rune tokens, we need to check the CREATE2 formula, to come up with the same address
        // Or for the case of BTC, we already know what is the BTC token address
        // If a token is requesting withdrawal that is not supported we just revert the tx.
        // Note: This should fail if there is not enough BTC to pay for the gas.
    }

    function extractSenderAndProxyFromTx(bytes32 txid) internal returns (address sender, address proxyWallet) {
        // TODO: Call pre-compile
        // This will decode a tx. First input will be the `sender` and
        // the address inscripted in the script is the `proxyWallet`
    }

    /**
     * TODO: Call pre-compile
     * Parse the transaction, and extract calls.
     * Verify that the msg.sender matches tokenId and version.
     * Different processor may be invoked based on the token ID (e.g. BTC vs Rune)
     */
    function processTx(uint tokenId, uint version, bytes32 txid) internal returns (
        uint64 block,
        uint64 timestamp,
        TransferItem[] memory inputs,
        TransferItem[] memory outputs,
        bytes memory encodedCall // includes targetNetwork, beneficiary, targetContract, methodCall, fee
    ) {
    }
}