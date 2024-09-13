import hre from "hardhat"

async function main() {
    const pocAddress = "0xbf18631e92A21b1DD4C6Cc49CF6A0d500A41f74A"
    const poc = await hre.ethers.getContractAt("QuantumPortalPocUpgradeable", pocAddress)

    console.log(await poc.feeToken())
}

main().then(() => process.exit(0))
