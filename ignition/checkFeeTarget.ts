import { ethers } from "ethers";
import hre from "hardhat";

const rpcUrl = "http://localhost:8545"

// Create a provider
const provider = new ethers.JsonRpcProvider(rpcUrl);
const abi = [{
    "inputs": [],
    "name": "WFRM",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },]

async function sendTransaction() {
    
    const gatewayAddr = "0x434eD9c890b58df314a5b243cBf00a768C41Cc7c"
    const gatewayProxy = new ethers.Contract(gatewayAddr, abi, provider);

    console.log(await gatewayProxy.WFRM());

}

sendTransaction();
