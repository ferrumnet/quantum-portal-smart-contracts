import { ethers } from "ethers";
import configModule from "./modules/QPDeploy"
import hre from "hardhat";

const rpcUrl = "https://testnet.dev.svcs.ferrumnetwork.io"

// Create a provider
const provider = new ethers.JsonRpcProvider(rpcUrl);

async function sendTransaction() {
    // const { gateway,
    //     ledgerMgr,
    //     poc,
    //     authMgr,
    //     feeConverterDirect,
    //     staking,
    //     minerMgr
    // } = await hre.ignition.deploy(configModule)

    console.log( hre.network.config.gas)
    
    hre.network.config.gasPrice = 40000000000000
    console.log( hre.network.config.gasPrice)
}

sendTransaction();
