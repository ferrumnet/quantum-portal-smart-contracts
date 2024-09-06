import { ethers } from "ethers";

const rpcUrl = "https://testnet.dev.svcs.ferrumnetwork.io" // testnet

// Create a provider
const provider = new ethers.JsonRpcProvider(rpcUrl);
const privateKey = process.env.QP_DEPLOYER_KEY!;
const wallet = new ethers.Wallet(privateKey, provider);
const contractAddress = "0x2927ec4185210FA20cf5d86B84B16E8fE064fF97"

const abi = [
    {
      "inputs": [
        {
          "internalType": "address",
          "name": "_address",
          "type": "address"
        }
      ],
      "name": "forceRemoveFromQuorum",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
  ]


async function sendTransaction() {
  
    const contract = new ethers.Contract(contractAddress, abi, wallet);
    const txResponse = await contract.forceRemoveFromQuorum("0xCcEE8000aaA01484112DfC0865d288de43940DEA")

    console.log("Transaction sent! Hash:", txResponse.hash);

    // Wait for the transaction to be mined
    const receipt = await txResponse.wait();
    console.log("Transaction confirmed in block:", receipt!.blockNumber);
}

sendTransaction();
