import hre from "hardhat"

async function main() {
    const pocAddress = "0x1E3F17291e8ae39104351AB8CceE1D241408c333"
    const poc = await hre.ethers.getContractAt("QuantumPortalPocUpgradeable", pocAddress)

    console.log(await poc.feeToken())
}

main().then(() => process.exit(0))
