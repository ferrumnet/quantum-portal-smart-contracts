import hre from "hardhat"
import deployModule from "../ignition/modules/QPDeploy"


async function main() {
    const { gateway,
        ledgerMgr,
        poc,
        authMgr,
        feeConverterDirect,
        staking,
        minerMgr
    } = await hre.ignition.deploy(deployModule)
    
}


main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error)
    process.exit(1)
})
