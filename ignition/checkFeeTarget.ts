import { ethers } from "ethers";

const rpcUrl = "http://localhost:8545"

// Create a provider
const provider = new ethers.JsonRpcProvider(rpcUrl);
const abi = [
    {
        "inputs": [],
        "name": "feeConvertor",
        "outputs": [
            {
            "internalType": "address",
            "name": "",
            "type": "address"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    }
]

async function sendTransaction() {
    try {
        const poc = new ethers.Contract("0xd8ad656fa118c5d4f4d02910a295fdce659a4267", abi, provider);
        console.log(await poc.feeConvertor())
    } catch (error) {
        console.error("Error sending transaction:", error);
    }
}

sendTransaction();
