import hre from "hardhat"

async function main() {
    const pocAddress = "0x0d2B09f34FD5888a01571ea56f52c9565639afca"
    const wallet = (await hre.ethers.getSigners())[0]
    const poc = await hre.ethers.getContractAt("QuantumPortalPocUpgradeable", pocAddress, wallet)

    await poc.setFeeToken("0x0000000000000000000000000000000000010001")
}

main().then(() => process.exit(0))
