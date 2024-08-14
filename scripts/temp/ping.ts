import { ethers } from "ethers";

const rpcUrl = "https://nd-829-997-700.p2pify.com/790712c620e64556719c7c9f19ef56e3" // Arbitrum
// const rpcUrl = "https://bsc-dataseed2.defibit.io" // bsc
// const rpcUrl = "https://base-mainnet.core.chainstack.com/e7aa01c976c532ebf8e2480a27f18278" // base

// Create a provider
const provider = new ethers.JsonRpcProvider(rpcUrl);
const privateKey = process.env.QP_DEPLOYER_KEY!;
const wallet = new ethers.Wallet(privateKey, provider);
const contractAddress = "0xe817f160A009AABb53a6b6c7DBBF482682fFc6f1"
const erc20abi = [
    {
      "inputs": [
        {
          "internalType": "address",
          "name": "_portal",
          "type": "address"
        },
        {
          "internalType": "uint64",
          "name": "_serverChainId",
          "type": "uint64"
        },
        {
          "internalType": "address",
          "name": "_serverAddress",
          "type": "address"
        },
        {
          "internalType": "uint256",
          "name": "_feeAmount",
          "type": "uint256"
        }
      ],
      "stateMutability": "nonpayable",
      "type": "constructor"
    },
    {
      "inputs": [],
      "name": "NotServer",
      "type": "error"
    },
    {
      "inputs": [
        {
          "internalType": "address",
          "name": "owner",
          "type": "address"
        }
      ],
      "name": "OwnableInvalidOwner",
      "type": "error"
    },
    {
      "inputs": [
        {
          "internalType": "address",
          "name": "account",
          "type": "address"
        }
      ],
      "name": "OwnableUnauthorizedAccount",
      "type": "error"
    },
    {
      "anonymous": false,
      "inputs": [
        {
          "indexed": false,
          "internalType": "address",
          "name": "admin",
          "type": "address"
        }
      ],
      "name": "AdminSet",
      "type": "event"
    },
    {
      "anonymous": false,
      "inputs": [
        {
          "indexed": true,
          "internalType": "address",
          "name": "previousOwner",
          "type": "address"
        },
        {
          "indexed": true,
          "internalType": "address",
          "name": "newOwner",
          "type": "address"
        }
      ],
      "name": "OwnershipTransferred",
      "type": "event"
    },
    {
      "inputs": [],
      "name": "admin",
      "outputs": [
        {
          "internalType": "address",
          "name": "",
          "type": "address"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "feeAmount",
      "outputs": [
        {
          "internalType": "uint256",
          "name": "",
          "type": "uint256"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "address",
          "name": "_portal",
          "type": "address"
        }
      ],
      "name": "initializeWithQp",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "numbPings",
      "outputs": [
        {
          "internalType": "uint256",
          "name": "",
          "type": "uint256"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "owner",
      "outputs": [
        {
          "internalType": "address",
          "name": "",
          "type": "address"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "ping",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "portal",
      "outputs": [
        {
          "internalType": "contract IQuantumPortalPoc",
          "name": "",
          "type": "address"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "receivePongResponse",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "uint256",
          "name": "",
          "type": "uint256"
        }
      ],
      "name": "remotePeers",
      "outputs": [
        {
          "internalType": "address",
          "name": "",
          "type": "address"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "uint256[]",
          "name": "chainIds",
          "type": "uint256[]"
        }
      ],
      "name": "removeRemotePeers",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "renounceOwnership",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "serverAddress",
      "outputs": [
        {
          "internalType": "address",
          "name": "",
          "type": "address"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "address",
          "name": "_admin",
          "type": "address"
        }
      ],
      "name": "setAdmin",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "address",
          "name": "newOwner",
          "type": "address"
        }
      ],
      "name": "transferOwnership",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "uint256",
          "name": "_feeAmount",
          "type": "uint256"
        }
      ],
      "name": "updateFeeAmount",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "address",
          "name": "_portal",
          "type": "address"
        }
      ],
      "name": "updatePortal",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
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
    },
    {
      "inputs": [
        {
          "internalType": "address",
          "name": "_serverAddress",
          "type": "address"
        }
      ],
      "name": "updateServerAddress",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    }
  ]


async function sendTransaction() {
    const contract = new ethers.Contract(contractAddress, erc20abi, wallet);
    const txResponse = await contract.ping()

    console.log("Transaction sent! Hash:", txResponse.hash);

    // Wait for the transaction to be mined
    const receipt = await txResponse.wait();
    console.log("Transaction confirmed in block:", receipt!.blockNumber);
}

sendTransaction();
