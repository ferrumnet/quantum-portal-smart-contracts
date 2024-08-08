import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import { Wei } from 'foundry-contracts/dist/test/common/Utils';
import { ZeroAddress } from "ethers";
import { loadQpDeployConfig, QpDeployConfig } from "../../scripts/utils/DeployUtils";
const DEFAULT_QP_CONFIG_FILE = 'QpDeployConfig.yaml';


const deployModule = buildModule("DeployModule", (m) => {
    const currentChainId = hre.network.config.chainId;
    const conf: QpDeployConfig = loadQpDeployConfig(process.env.QP_CONFIG_FILE || DEFAULT_QP_CONFIG_FILE);
    const owner = m.getAccount(0)

    //--------------- Gateway ----------------//
    const gatewayImpl = m.contract("QuantumPortalGatewayUpgradeableTest", [conf.FRM[currentChainId!]], { id: "QPGatewayImpl"})
    let initializeCalldata: any = m.encodeFunctionCall(gatewayImpl, "initialize", [
		owner,
		owner
	]);
    const gateway = m.contract("ERC1967Proxy", [gatewayImpl, initializeCalldata], { id: "Gateway"})

    //--------------- LedgerManager -----------//
    const ledgerMgrImpl = m.contract("QuantumPortalLedgerMgrImplUpgradeable", [], { id: "LedgerMgrImpl"})
    initializeCalldata = m.encodeFunctionCall(ledgerMgrImpl, "initialize", [
        owner,
        owner,
        conf.QuantumPortalMinStake!,
        gateway
    ]);
    const ledgerMgr = m.contract("ERC1967Proxy", [ledgerMgrImpl, initializeCalldata], { id: "LedgerMgr"})

    //--------------- Poc ---------------------//
    const pocImpl = m.contract("QuantumPortalPocImplUpgradeable", [], { id: "PocImpl"})
    initializeCalldata = m.encodeFunctionCall(pocImpl, "initialize", [
        owner,
        owner,
        gateway
    ]);
    const poc = m.contract("ERC1967Proxy", [pocImpl, initializeCalldata], { id: "Poc"})

    //--------------- AuthorityManager --------//
    const authMgrImpl = m.contract("QuantumPortalAuthorityMgrUpgradeable", [], { id: "AuthMgrImpl"})
    initializeCalldata = m.encodeFunctionCall(authMgrImpl, "initialize", [
        ledgerMgr,
        poc,
        owner,
        owner,
        gateway
    ]);
    const authMgr = m.contract("ERC1967Proxy", [authMgrImpl, initializeCalldata], { id: "AuthMgr"})

    //--------------- Oracle ------------------//
    const oracle = m.contract("UniswapOracle", [conf.UniV2Factory[currentChainId!]], { id: "Oracle"})

    //--------------- FeeConverter ------------//
    const feeConverterImpl = m.contract("QuantumPortalFeeConverterUpgradeable", [], { id: "FeeConverterImpl"})
    initializeCalldata = m.encodeFunctionCall(feeConverterImpl, "initialize", [
        conf.WETH[currentChainId!],
        conf.FRM[currentChainId!],
        oracle,
        gateway
    ]);
    const feeConverter = m.contract("ERC1967Proxy", [feeConverterImpl, initializeCalldata], { id: "FeeConverter"})

    //--------------- StakeWithDelegate -------//
    const stakingImpl = m.contract("QuantumPortalStakeWithDelegateUpgradeable", [], { id: "StakingImpl"})
    initializeCalldata = m.encodeFunctionCall(stakingImpl, "initialize", [
        conf.FRM[currentChainId!],
        authMgr,
        ZeroAddress,
        gateway
    ]);
    const staking = m.contract("ERC1967Proxy", [stakingImpl, initializeCalldata], { id: "Staking"})

    //---------------- MiningManager ----------//
    const minerMgrImpl = m.contract("QuantumPortalMinerMgrUpgradeable", [], { id: "MinerMgrImpl"})
    initializeCalldata = m.encodeFunctionCall(minerMgrImpl, "initialize", [
        staking,
        poc,
        ledgerMgr,
        gateway
    ]);
    const minerMgr = m.contract("ERC1967Proxy", [minerMgrImpl, initializeCalldata], { id: "MinerMgr"})

    //----------------- Setup -----------------//
    m.call(ledgerMgr, "updateAuthorityMgr", [authMgr])
	m.call(ledgerMgr, "updateMinerMgr", [minerMgr])
	m.call(ledgerMgr, "updateFeeConvertor", [feeConverter])

    m.call(poc, "setManager", [ledgerMgr])
	m.call(poc, "updateFeeTarget", [])
	m.call(poc, "setFeeToken", [conf.FRM[currentChainId!]])

	m.call(minerMgr, "updateBaseToken", [conf.FRM[currentChainId!]])
	m.call(ledgerMgr, "updateLedger", [poc])

    return {
        gateway,
        ledgerMgr,
        poc,
        authMgr,
        oracle,
        feeConverter,
        staking,
        minerMgr
    }
})

export default deployModule;
