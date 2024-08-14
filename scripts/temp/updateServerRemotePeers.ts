import { ethers } from "ethers";

// const rpcUrl = "https://nd-829-997-700.p2pify.com/790712c620e64556719c7c9f19ef56e3"
const rpcUrl = "https://base-mainnet.core.chainstack.com/e7aa01c976c532ebf8e2480a27f18278" // base

// Create a provider
const provider = new ethers.JsonRpcProvider(rpcUrl);
const privateKey = process.env.QP_DEPLOYER_KEY!;
const wallet = new ethers.Wallet(privateKey, provider);
const contractAddress = "0x4bcBA75cdcAAa7b231b493b5a73E00BA76607557"
const serverAbi = [
    {
      "inputs": [
        {
          "internalType": "uint256[]",
          "name": "chainIds",
          "type": "uint256[]"
        },
        {
          "internalType": "address[]",
          "name": "remotes",
          "type": "address[]"
        }
      ],
      "name": "updateRemotePeers",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    }
]

// client: 0xe817f160A009AABb53a6b6c7DBBF482682fFc6f1
// server: 0x4bcBA75cdcAAa7b231b493b5a73E00BA76607557

async function sendTransaction() {
    const contract = new ethers.Contract(contractAddress, serverAbi, wallet);
    const clientAddress = "0xe817f160A009AABb53a6b6c7DBBF482682fFc6f1"
    const txResponse = await contract.updateRemotePeers(
        [42161],
        [clientAddress]
    )

    console.log("Transaction sent! Hash:", txResponse.hash);

    // Wait for the transaction to be mined
    const receipt = await txResponse.wait();
    console.log("Transaction confirmed in block:", receipt!.blockNumber);
}

sendTransaction();
