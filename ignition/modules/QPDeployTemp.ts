import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import { ZeroAddress, FunctionFragment } from "ethers";
import { loadQpDeployConfig, QpDeployConfig } from "../../scripts/utils/DeployUtils";
const DEFAULT_QP_CONFIG_FILE = 'QpDeployConfig.yaml';


const BETA_QUORUM_ID = "0x0000000000000000000000000000000000000457"
const PROD_QUORUM_ID = "0x00000000000000000000000000000000000008AE"
const TIMELOCKED_PROD_QUORUM_ID = "0x0000000000000000000000000000000000000d05"

const deployModule = buildModule("DeployModule", (m) => {
    
    const currentChainId = 26100
    const conf: QpDeployConfig = loadQpDeployConfig(process.env.QP_CONFIG_FILE || DEFAULT_QP_CONFIG_FILE);
    const owner = m.getAccount(0)

    //--------------- Gateway ----------------//
    const gatewayImpl = m.contract("QuantumPortalGatewayUpgradeable", ["0x0000000000000000000000000000000000000000"], { id: "QPGatewayImpl"})

    const timelockPeriod = 60 * 60 * 24 * 1 // 1 day

    let initializeCalldata: any = m.encodeFunctionCall(gatewayImpl, "initialize", [
        timelockPeriod,
		owner,
		owner
	]);
    const gatewayProxy = m.contract("ERC1967Proxy", [gatewayImpl, initializeCalldata], { id: "GatewayProxy"})
    const gateway = m.contractAt("QuantumPortalGatewayUpgradeable", gatewayProxy, { id: "Gateway"})

    //--------------- Poc ---------------------//
    const pocImpl = m.contract("QuantumPortalPocImplUpgradeable", [], { id: "PocImpl"})
    initializeCalldata = m.encodeFunctionCall(pocImpl, "initialize", [
        owner,
        owner,
    ]);
    const pocProxy = m.contract("ERC1967Proxy", [pocImpl, initializeCalldata], { id: "PocProxy"})
    const poc = m.contractAt("QuantumPortalPocImplUpgradeable", pocProxy, { id: "Poc"})


    //----------------- Setup -----------------//
	m.call(poc, "setFeeToken", [conf.FRM[currentChainId!]])

    m.call(gateway, "initializeQuorum", [BETA_QUORUM_ID, 0, 2, 0, ["0xEb608fE026a4F54df43E57A881D2e8395652C58D", "0xdCd60Be5b153d1884e1E6E8C23145D6f3546315e"]])

    const settings = [{
        quorumId: BETA_QUORUM_ID,
        target: poc,
        funcSelector: FunctionFragment.getSelector("setFeeToken", ["address"]),
    }]

    m.call(gateway, "setCallAuthLevels", [settings])
    m.call(poc, "setAdmin", [gateway])
    m.call(poc, "transferOwnership", [gateway])
    // SET FEEPERBYTE ON FEECONVERTERDIRECT

    return {
        gateway,
        poc,
    }
})


export default deployModule;
