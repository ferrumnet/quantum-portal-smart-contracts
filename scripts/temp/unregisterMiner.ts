import { ethers } from "ethers";

const rpcUrl = "https://testnet.dev.svcs.ferrumnetwork.io" // testnet

// Create a provider
const provider = new ethers.JsonRpcProvider(rpcUrl);
const privateKey = process.env.QP_DEPLOYER_KEY!;
const wallet = new ethers.Wallet(privateKey, provider);
const ledgerMgrAddress = "0x2381E4d8fB6fD92cAF233B2eDa8f70beaDF2932f"

const abi = [
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "miner",
        "type": "address"
      }
    ],
    "name": "unregisterMiner",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
]


async function sendTransaction() {
  
    const contract = new ethers.Contract(ledgerMgrAddress, abi, wallet);
    const txResponse = await contract.unregisterMiner("0xCcEE8000aaA01484112DfC0865d288de43940DEA")

    console.log("Transaction sent! Hash:", txResponse.hash);

    // Wait for the transaction to be mined
    const receipt = await txResponse.wait();
    console.log("Transaction confirmed in block:", receipt!.blockNumber);
}

sendTransaction();
