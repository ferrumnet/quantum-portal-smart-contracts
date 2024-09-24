import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import { FunctionFragment } from "ethers";
import { loadQpDeployConfigSync, QpDeployConfig } from "../../scripts/utils/DeployUtils";
const DEFAULT_QP_CONFIG_FILE = 'QpDeployConfig.yaml';


const BETA_QUORUM_ID = "0x0000000000000000000000000000000000000457"
const PROD_QUORUM_ID = "0x00000000000000000000000000000000000008AE"
const TIMELOCKED_PROD_QUORUM_ID = "0x0000000000000000000000000000000000000d05"

const deployModule = buildModule("DeployModule", (m) => {
    
    const currentChainId = 26100
    const conf: QpDeployConfig = loadQpDeployConfigSync(process.env.QP_CONFIG_FILE || DEFAULT_QP_CONFIG_FILE);
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

    m.call(gateway, "initializeQuorum", [BETA_QUORUM_ID, 0, 2, 0, ["0x286220e71bF9F7c7c4a0dC57b05Bd8C0855bed65", "0x4916B25FD967fa68A768AD664Ac6ae9E6B3ebBC2", "0x4Fc04C32Ef673A926120CC7747D1d2c05BA76516"]])

    const settings = [{
        quorumId: BETA_QUORUM_ID,
        target: gateway,
        funcSelector: FunctionFragment.getSelector("initializeQuorum", ["address", "uint64", "uint16", "uint8", "address[]"]),
    },
    {
        quorumId: BETA_QUORUM_ID,
        target: gateway,
        funcSelector: FunctionFragment.getSelector("updateQpAddresses", ["address", "address", "address"]),
    },
    {
        quorumId: BETA_QUORUM_ID,
        target: gateway,
        funcSelector: FunctionFragment.getSelector("setCallAuthLevels", ["(address,address,bytes4)[]"]),
    },
    {
        quorumId: BETA_QUORUM_ID,
        target: gateway,
        funcSelector: FunctionFragment.getSelector("updateTimelockPeriod", ["uint256"]),
    },
    {
        quorumId: BETA_QUORUM_ID,
        target: gateway,
        funcSelector: FunctionFragment.getSelector("addDevAccounts", ["address[]"]),
    },
    {
        quorumId: BETA_QUORUM_ID,
        target: gateway,
        funcSelector: FunctionFragment.getSelector("removeDevAccounts", ["address[]"]),
    },
    {
        quorumId: BETA_QUORUM_ID,
        target: poc,
        funcSelector: FunctionFragment.getSelector("setFeeToken", ["address"]),
    },
    {
        quorumId: BETA_QUORUM_ID,
        target: poc,
        funcSelector: FunctionFragment.getSelector("setNativeFeeRepo", ["address"]),
    },
    {
        quorumId: BETA_QUORUM_ID,
        target: poc,
        funcSelector: FunctionFragment.getSelector("setManager", ["address"]),
    }]

    m.call(gateway, "setCallAuthLevels", [settings])
    // m.call(poc, "setAdmin", [gateway])
    // m.call(poc, "transferOwnership", [gateway])
    // SET FEEPERBYTE ON FEECONVERTERDIRECT

    return {
        gateway,
        poc,
    }
})


export default deployModule;
