import { ethers } from "ethers";
import hre from "hardhat";

// Create a provider
const pocAddress = "0xd6BCe4677a9F00f85AF02dD5D19EA52fF14EDd05"
const wfrmAddress = "0xA719b8aB7EA7AF0DDb4358719a34631bb79d15Dc"


async function sendTransaction() {
    const wallet = (await hre.ethers.getSigners())[0]
    const wfrm = await hre.ethers.getContractAt("TestToken", wfrmAddress, wallet)
    const portal = await hre.ethers.getContractAt("QuantumPortalPocImplUpgradeable", pocAddress, wallet)

    console.log("Balance: " + (await wfrm.balanceOf(wallet.address)).toString())
    // const feeTx = await wfrm.transfer((await portal.feeTarget()), ethers.parseEther("1"))
    // await feeTx.wait()
    // console.log("Fee sent")

    const txResponse = await portal.run(26100, "0x5fe476edF6F4c47F511466B01E5a9c031c35379A", "0x5fe476edF6F4c47F511466B01E5a9c031c35379A", "0x12345678")

    const receipt = await txResponse.wait();
    console.log("Transaction confirmed in block:", receipt!.blockNumber);
}

sendTransaction();
