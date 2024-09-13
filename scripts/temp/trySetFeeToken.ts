import { FunctionFragment } from "ethers"
import hre from "hardhat"

async function main() {
    const pocAddress = "0x3C9025571EA627431570C1aB2ea74617a1c30B40"
    const wallet = (await hre.ethers.getSigners())[0]
    const BETA_QUORUM_ID = "0x0000000000000000000000000000000000000457"
    const gateway = await hre.ethers.getContractAt("QuantumPortalGatewayUpgradeable", pocAddress, wallet)

    console.log(await wallet.address)
    
    // await gateway.setCallAuthLevels([{
    //     quorumId: BETA_QUORUM_ID,
    //     target: gateway,
    //     funcSelector: FunctionFragment.getSelector("setAdmin", ["address"]),
    // }])

    console.log(await gateway.setAdmin(gateway.target))
}

main().then(() => process.exit(0))
