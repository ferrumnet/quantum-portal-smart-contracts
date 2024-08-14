import { ethers } from "ethers";


// Create a provider

const walletArb = new ethers.Wallet(process.env.QP_DEPLOYER_KEY!, new ethers.JsonRpcProvider("https://nd-829-997-700.p2pify.com/790712c620e64556719c7c9f19ef56e3"));
const walletBase = new ethers.Wallet(process.env.QP_DEPLOYER_KEY!, new ethers.JsonRpcProvider("https://base-mainnet.core.chainstack.com/e7aa01c976c532ebf8e2480a27f18278"));
const walletBsc = new ethers.Wallet(process.env.QP_DEPLOYER_KEY!, new ethers.JsonRpcProvider("https://bsc-dataseed2.defibit.io"));
const walletFerrumtestnet = new ethers.Wallet(process.env.QP_DEPLOYER_KEY!, new ethers.JsonRpcProvider("https://testnet.dev.svcs.ferrumnetwork.io"));

const clientAddress = "0x2Df204F847ca062624E34bB073dAe0c96da444ea"
const serverAddress = "0x2383151734a78246cC553d549a5B03fA95E857fD"
const clientPongAbi = [{"inputs":[{"internalType":"address","name":"_portal","type":"address"},{"internalType":"uint64","name":"_serverChainId","type":"uint64"},{"internalType":"address","name":"_serverAddress","type":"address"},{"internalType":"uint256","name":"_feeAmount","type":"uint256"}],"stateMutability":"nonpayable","type":"constructor"},{"inputs":[],"name":"NotServer","type":"error"},{"inputs":[{"internalType":"address","name":"owner","type":"address"}],"name":"OwnableInvalidOwner","type":"error"},{"inputs":[{"internalType":"address","name":"account","type":"address"}],"name":"OwnableUnauthorizedAccount","type":"error"},{"anonymous":false,"inputs":[{"indexed":false,"internalType":"address","name":"admin","type":"address"}],"name":"AdminSet","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"previousOwner","type":"address"},{"indexed":true,"internalType":"address","name":"newOwner","type":"address"}],"name":"OwnershipTransferred","type":"event"},{"inputs":[],"name":"admin","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"feeAmount","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_portal","type":"address"}],"name":"initializeWithQp","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"numbPings","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"owner","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"ping","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"portal","outputs":[{"internalType":"contract IQuantumPortalPoc","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"receivePongResponse","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"","type":"uint256"}],"name":"remotePeers","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"uint256[]","name":"chainIds","type":"uint256[]"}],"name":"removeRemotePeers","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"renounceOwnership","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"serverAddress","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_admin","type":"address"}],"name":"setAdmin","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"newOwner","type":"address"}],"name":"transferOwnership","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256","name":"_feeAmount","type":"uint256"}],"name":"updateFeeAmount","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_portal","type":"address"}],"name":"updatePortal","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"uint256[]","name":"chainIds","type":"uint256[]"},{"internalType":"address[]","name":"remotes","type":"address[]"}],"name":"updateRemotePeers","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_serverAddress","type":"address"}],"name":"updateServerAddress","outputs":[],"stateMutability":"nonpayable","type":"function"}]


async function sendTransaction() {
    const clientArb = new ethers.Contract(clientAddress, clientPongAbi, walletArb);
    const clientBase = new ethers.Contract(clientAddress, clientPongAbi, walletBase);
    const clientBsc = new ethers.Contract(clientAddress, clientPongAbi, walletBsc);
    const serverFerrumtestnet = new ethers.Contract(serverAddress, clientPongAbi, walletFerrumtestnet);

    const txResponseArb = await clientArb.updateFeeAmount(1000000000000000000n)
    console.log("Arb tx sent. Hash:", txResponseArb.hash)
    const txResponseBase = await clientBase.updateFeeAmount(1000000000000000000n)
    console.log("Base tx sent. Hash:", txResponseBase.hash)
    const txResponseBsc = await clientBsc.updateFeeAmount(1000000000000000000n)
    console.log("Bsc tx sent. Hash:", txResponseBsc.hash)
    const txResponseFerrumtestnet = await serverFerrumtestnet.updateFeeAmount(1000000000000000000n)
    console.log("Ferrumtestnet tx sent. Hash:", txResponseFerrumtestnet.hash)
}

sendTransaction();
