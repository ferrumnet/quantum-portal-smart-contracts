import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import { Wei } from 'foundry-contracts/dist/test/common/Utils';
import { ZeroAddress } from "ethers";
import { loadQpDeployConfig, QpDeployConfig } from "../../scripts/utils/DeployUtils";
const DEFAULT_QP_CONFIG_FILE = 'QpDeployConfig.yaml';


const upgradeModule = buildModule("DeployModule", (m) => {
    
})

export default upgradeModule;
