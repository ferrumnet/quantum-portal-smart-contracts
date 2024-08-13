import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import { ZeroAddress } from "ethers";
import { loadQpDeployConfig, QpDeployConfig } from "../../scripts/utils/DeployUtils";
const DEFAULT_QP_CONFIG_FILE = 'QpDeployConfig.yaml';


const deployModule = buildModule("DeployModule", (m) => {


    const poc = m.contractAt("QuantumPortalPocImplUpgradeable", "0x968D9e7De42b224a67E131EE26893Ef3dC846A1e", { id: "Poc"})
    
	m.call(poc, "updateFeeTarget")
    return {
        poc
    }
})

export default deployModule;
