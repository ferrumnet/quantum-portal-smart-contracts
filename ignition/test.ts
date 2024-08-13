import deployModule from "./modules/QPDeploy"
import feeTargetmodule from "./modules/QPFeeTarget"
import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import { ZeroAddress } from "ethers";
import { loadQpDeployConfig, QpDeployConfig } from "../scripts/utils/DeployUtils";
const DEFAULT_QP_CONFIG_FILE = 'QpDeployConfig.yaml';


async function main() {
    console.log(hre.network.config.chainId)
    const {
        gateway,
        ledgerMgr,
        poc,
        authMgr,
        oracle,
        feeConverter,
        staking,
        minerMgr
    } = await hre.ignition.deploy(deployModule)

    console.log(await poc.feeTarget())
    console.log(await ledgerMgr.minerMgr())

    // await poc.updateFeeTarget("0x7F511eA43167af094fEf24b5d3b23c5837D5Cf71")

    // console.log(await poc.feeTarget())
    // console.log(await ledgerMgr.minerMgr())
    
    await hre.ignition.deploy(feeTargetmodule)
    console.log(await poc.feeTarget())


    // const {
    //     poc
    // } = await hre.ignition.deploy(feeTargetmodule)

    // console.log(poc.target)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });