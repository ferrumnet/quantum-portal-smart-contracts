import { FunctionFragment } from "ethers"
import hre from "hardhat"

async function main() {
    const qpContractAddress = "0x7621c803B6553dF43EF03D5e3736A0A36459BbcA"
    const wallet = (await hre.ethers.getSigners())[0]
    const qpContract = await hre.ethers.getContractAt("WithAdmin", qpContractAddress, wallet) as any

    const tx = await qpContract.setAdmin("0x17C5B49A55466Ff60ca4e6Dfd40d5a0F40ac137a", { gasLimit: 30000000 })  
    await tx.wait()
}

main().then(() => process.exit(0))
