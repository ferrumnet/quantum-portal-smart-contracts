import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import { ZeroAddress, FunctionFragment } from "ethers";
import { loadQpDeployConfig, QpDeployConfig } from "../../scripts/utils/DeployUtils";
const DEFAULT_QP_CONFIG_FILE = 'QpDeployConfig.yaml';


const BETA_QUORUM_ID = "0x0000000000000000000000000000000000000457"
const PROD_QUORUM_ID = "0x00000000000000000000000000000000000008AE"
const TIMELOCKED_PROD_QUORUM_ID = "0x0000000000000000000000000000000000000d05"

const deployModule = buildModule("DeployModule", (m) => {
    
    const owner = m.getAccount(0)

    const poc = m.contractAt("QuantumPortalPocImplUpgradeable", "0xF348a3D83ab349efC622731DD64c8c3bA4543b25")
    const feeConverterDirect = m.contractAt("QuantumPortalFeeConverterDirectUpgradeable", "0x8de74628Cb797f82B7FBc0d44C4D0c8DBeE4B7d1")

    //---------------- NativeFeeRepo -------------//
    const nativeFeeRepoImpl = m.contract("QuantumPortalNativeFeeRepoBasicUpgradeable", [], { id: "NativeFeeRepoImpl"})

    let initializeCalldata = m.encodeFunctionCall(nativeFeeRepoImpl, "initialize", [
        poc,
        feeConverterDirect,
        owner,
        owner
    ])
    const nativeFeeRepoProxy = m.contract("ERC1967Proxy", [nativeFeeRepoImpl, initializeCalldata], { id: "NativeFeeRepoProxy"})
    const nativeFeeRepo = m.contractAt("QuantumPortalNativeFeeRepoBasicUpgradeable", nativeFeeRepoProxy, { id: "NativeFeeRepo"})

    m.call(poc, "setNativeFeeRepo", [nativeFeeRepo])

    // SET FEEPERBYTE ON FEECONVERTERDIRECT

    return {
        nativeFeeRepo
    }
})


export default deployModule;
