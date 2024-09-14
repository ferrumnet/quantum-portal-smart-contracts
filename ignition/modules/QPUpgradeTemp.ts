import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import { ZeroAddress, FunctionFragment } from "ethers";
import { loadQpDeployConfig, loadQpDeployConfigSync, QpDeployConfig } from "../../scripts/utils/DeployUtils";
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

    //--------------- LedgerManager -----------//
    const ledgerMgrImpl = m.contract("QuantumPortalLedgerMgrImplUpgradeable", [], { id: "LedgerMgrImpl"})
    initializeCalldata = m.encodeFunctionCall(ledgerMgrImpl, "initialize", [
        owner,
        owner,
        conf.QuantumPortalMinStake!,
    ]);
    const ledgerMgrProxy = m.contract("ERC1967Proxy", [ledgerMgrImpl, initializeCalldata], { id: "LedgerMgrProxy"})
    const ledgerMgr = m.contractAt("QuantumPortalLedgerMgrImplUpgradeable", ledgerMgrProxy, { id: "LedgerMgr"})

    //--------------- Poc ---------------------//
    const pocImpl = m.contract("QuantumPortalPocImplUpgradeable", [], { id: "PocImpl"})
    initializeCalldata = m.encodeFunctionCall(pocImpl, "initialize", [
        owner,
        owner,
    ]);
    const pocProxy = m.contract("ERC1967Proxy", [pocImpl, initializeCalldata], { id: "PocProxy"})
    const poc = m.contractAt("QuantumPortalPocImplUpgradeable", pocProxy, { id: "Poc"})

    //--------------- AuthorityManager --------//
    const authMgrImpl = m.contract("QuantumPortalAuthorityMgrUpgradeable", [], { id: "AuthMgrImpl"})
    initializeCalldata = m.encodeFunctionCall(authMgrImpl, "initialize", [
        ledgerMgr,
        poc,
        owner,
        owner,
    ]);
    const authMgrProxy = m.contract("ERC1967Proxy", [authMgrImpl, initializeCalldata], { id: "AuthMgrProxy"})
    const authMgr = m.contractAt("QuantumPortalAuthorityMgrUpgradeable", authMgrProxy, { id: "AuthMgr"})

    // //--------------- Oracle ------------------//
    // // const oracle = m.contract("UniswapOracle", [conf.UniV2Factory[currentChainId!]], { id: "Oracle"})

    //--------------- FeeConverterDirect ------------//
    const feeConverterDirectImpl = m.contract("QuantumPortalFeeConverterDirectUpgradeable", [], { id: "FeeConverterDirectImpl"})
    initializeCalldata = m.encodeFunctionCall(feeConverterDirectImpl, "initialize", [
        owner
    ]);
    const feeConverterDirectProxy = m.contract("ERC1967Proxy", [feeConverterDirectImpl, initializeCalldata], { id: "FeeConverterDirectProxy"})
    const feeConverterDirect = m.contractAt("QuantumPortalFeeConverterDirectUpgradeable", feeConverterDirectProxy, { id: "FeeConverterDirect"})

    //---------------- NativeFeeRepo -------------//
    const nativeFeeRepoImpl = m.contract("QuantumPortalNativeFeeRepoBasicUpgradeable", [], { id: "NativeFeeRepoImpl"})

    initializeCalldata = m.encodeFunctionCall(nativeFeeRepoImpl, "initialize", [
        poc,
        feeConverterDirect,
        owner,
        owner
    ])
    const nativeFeeRepoProxy = m.contract("ERC1967Proxy", [nativeFeeRepoImpl, initializeCalldata], { id: "NativeFeeRepoProxy"})
    const nativeFeeRepo = m.contractAt("QuantumPortalNativeFeeRepoBasicUpgradeable", nativeFeeRepoProxy, { id: "NativeFeeRepo"})


    //--------------- StakeWithDelegate -------//
    const stakingImpl = m.contract("QuantumPortalStakeWithDelegateUpgradeable", [], { id: "StakingImpl"})
    initializeCalldata = m.encodeFunctionCall(stakingImpl, "initialize(address,address,address,address)", [
        conf.FRM[currentChainId!],
        authMgr,
        ZeroAddress,
        owner
    ]);
    const stakingProxy = m.contract("ERC1967Proxy", [stakingImpl, initializeCalldata], { id: "StakingProxy"})
    const staking = m.contractAt("QuantumPortalStakeWithDelegateUpgradeable", stakingProxy, { id: "Staking"})

    //---------------- MiningManager ----------//
    const minerMgrImpl = m.contract("QuantumPortalMinerMgrUpgradeable", [], { id: "MinerMgrImpl"})
    initializeCalldata = m.encodeFunctionCall(minerMgrImpl, "initialize", [
        staking,
        poc,
        ledgerMgr,
        owner
    ]);
    const minerMgrProxy = m.contract("ERC1967Proxy", [minerMgrImpl, initializeCalldata], { id: "MinerMgrProxy"})
    const minerMgr = m.contractAt("QuantumPortalMinerMgrUpgradeable", minerMgrProxy, { id: "MinerMgr"})

    //----------------- Setup -----------------//
    m.call(ledgerMgr, "updateAuthorityMgr", [authMgr])
	m.call(ledgerMgr, "updateMinerMgr", [minerMgr])
	m.call(ledgerMgr, "updateFeeConvertor", [feeConverterDirect])

    m.call(poc, "setManager", [ledgerMgr])
	m.call(poc, "setFeeToken", [conf.FRM[currentChainId!]])
    m.call(poc, "setNativeFeeRepo", [nativeFeeRepo])
    
	m.call(minerMgr, "updateBaseToken", [conf.FRM[currentChainId!]])
	m.call(ledgerMgr, "updateLedger", [poc], { id: "UpdateLedgerOnLedgerMgr"})

    const settings  = [
        {
            quorumId: PROD_QUORUM_ID,
            target: gateway,
            funcSelector: FunctionFragment.getSelector("initializeQuorum", ["address", "uint64", "uint16", "uint8", "address[]"]),
        },
        {
            quorumId: PROD_QUORUM_ID,
            target: gateway,
            funcSelector: FunctionFragment.getSelector("updateQpAddresses", ["address", "address", "address"]),
        },
        {
            quorumId: TIMELOCKED_PROD_QUORUM_ID,
            target: gateway,
            funcSelector: FunctionFragment.getSelector("setCallAuthLevels", ["(address,address,bytes4)[]"]),
        },
        {
            quorumId: TIMELOCKED_PROD_QUORUM_ID,
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
            quorumId: PROD_QUORUM_ID,
            target: poc,
            funcSelector: FunctionFragment.getSelector("setNativeFeeRepo", ["address"]),
        },
        {
            quorumId: TIMELOCKED_PROD_QUORUM_ID,
            target: poc,
            funcSelector: FunctionFragment.getSelector("setManager", ["address"]),
        },
        {
            quorumId: TIMELOCKED_PROD_QUORUM_ID,
            target: ledgerMgr,
            funcSelector: FunctionFragment.getSelector("updateLedger", ["address"]),
        },
        {
            quorumId: TIMELOCKED_PROD_QUORUM_ID,
            target: ledgerMgr,
            funcSelector: FunctionFragment.getSelector("updateAuthorityMgr", ["address"]),
        },
        {
            quorumId: TIMELOCKED_PROD_QUORUM_ID,
            target: ledgerMgr,
            funcSelector: FunctionFragment.getSelector("updateMinerMg", ["address"]),
        },
        {
            quorumId: TIMELOCKED_PROD_QUORUM_ID,
            target: ledgerMgr,
            funcSelector: FunctionFragment.getSelector("updateFeeConvertor", ["address"]),
        },
        {
            quorumId: BETA_QUORUM_ID,
            target: ledgerMgr,
            funcSelector: FunctionFragment.getSelector("updateFeeTargets", ["address", "address"]),
        },
        {
            quorumId: PROD_QUORUM_ID,
            target: ledgerMgr,
            funcSelector: FunctionFragment.getSelector("updateMinerMinimumStake", ["uint256"]),
        },
        {
            quorumId: PROD_QUORUM_ID,
            target: ledgerMgr,
            funcSelector: FunctionFragment.getSelector("unregisterMiner", ["address"]),
        },
        {
            quorumId: BETA_QUORUM_ID,
            target: feeConverterDirect,
            funcSelector: FunctionFragment.getSelector("updateFeePerByte", ["uint256"]),
        },
        {
            quorumId: BETA_QUORUM_ID,
            target: feeConverterDirect,
            funcSelector: FunctionFragment.getSelector("setChainGasTokenPriceX128", ["uint256[]", "uint256[]"]),
        },
        {
            quorumId: TIMELOCKED_PROD_QUORUM_ID,
            target: authMgr,
            funcSelector: FunctionFragment.getSelector("updateLedgerMgr", ["address"]),
        },
        {
            quorumId: TIMELOCKED_PROD_QUORUM_ID,
            target: authMgr,
            funcSelector: FunctionFragment.getSelector("updatePortal", ["address"]),
        },
        {
            quorumId: PROD_QUORUM_ID,
            target: authMgr,
            funcSelector: FunctionFragment.getSelector("updateRemotePeers", ["uint256[]", "address[]"]),
        },
        {
            quorumId: PROD_QUORUM_ID,
            target: authMgr,
            funcSelector: FunctionFragment.getSelector("removeRemotePeers", ["uint256[]"]),
        },
        {
            quorumId: BETA_QUORUM_ID,
            target: authMgr,
            funcSelector: FunctionFragment.getSelector("updateBaseToken", ["address"]),
        },
        {
            quorumId: TIMELOCKED_PROD_QUORUM_ID,
            target: authMgr,
            funcSelector: FunctionFragment.getSelector("initializeQuorum", ["address", "uint64", "uint16", "uint8", "address[]"]),
        },
        {
            quorumId: PROD_QUORUM_ID,
            target: authMgr,
            funcSelector: FunctionFragment.getSelector("forceRemoveFromQuorum", ["address"]),
        },
        {
            quorumId: PROD_QUORUM_ID,
            target: staking,
            funcSelector: FunctionFragment.getSelector("updateStakeVerifyer", ["address"]),
        },
        {
            quorumId: PROD_QUORUM_ID,
            target: staking,
            funcSelector: FunctionFragment.getSelector("init", ["address", "string", "address[]"]),
        },
        {
            quorumId: BETA_QUORUM_ID,
            target: staking,
            funcSelector: FunctionFragment.getSelector("sweepToken", ["address", "address", "uint256"]),
        },
        {
            quorumId: BETA_QUORUM_ID,
            target: staking,
            funcSelector: FunctionFragment.getSelector("freezeSweep", []),
        },
        {
            quorumId: PROD_QUORUM_ID,
            target: staking,
            funcSelector: FunctionFragment.getSelector("setCreationSigner", ["address"]),
        },
        {
            quorumId: PROD_QUORUM_ID,
            target: staking,
            funcSelector: FunctionFragment.getSelector("setLockSeconds", ["address", "uint256"]),
        },
        {
            quorumId: TIMELOCKED_PROD_QUORUM_ID,
            target: minerMgr,
            funcSelector: FunctionFragment.getSelector("updateLedgerMgr", ["address"]),
        },
        {
            quorumId: TIMELOCKED_PROD_QUORUM_ID,
            target: minerMgr,
            funcSelector: FunctionFragment.getSelector("updatePortal", ["address"]),
        },
        {
            quorumId: PROD_QUORUM_ID,
            target: minerMgr,
            funcSelector: FunctionFragment.getSelector("updateRemotePeers", ["uint256[]", "address[]"]),
        },
        {
            quorumId: PROD_QUORUM_ID,
            target: minerMgr,
            funcSelector: FunctionFragment.getSelector("removeRemotePeers", ["uint256[]"]),
        },
        {
            quorumId: BETA_QUORUM_ID,
            target: minerMgr,
            funcSelector: FunctionFragment.getSelector("updateBaseToken", ["address"]),
        },
        // Upgrade calls
        {
            quorumId: TIMELOCKED_PROD_QUORUM_ID,
            target: gateway,
            funcSelector: FunctionFragment.getSelector("upgradeToAndCall", ["address", "bytes"]),
        },
        {
            quorumId: TIMELOCKED_PROD_QUORUM_ID,
            target: poc,
            funcSelector: FunctionFragment.getSelector("upgradeToAndCall", ["address", "bytes"]),
        },
        {
            quorumId: TIMELOCKED_PROD_QUORUM_ID,
            target: ledgerMgr,
            funcSelector: FunctionFragment.getSelector("upgradeToAndCall", ["address", "bytes"]),
        },
        {
            quorumId: TIMELOCKED_PROD_QUORUM_ID,
            target: feeConverterDirect,
            funcSelector: FunctionFragment.getSelector("upgradeToAndCall", ["address", "bytes"]),
        },
        {
            quorumId: TIMELOCKED_PROD_QUORUM_ID,
            target: authMgr,
            funcSelector: FunctionFragment.getSelector("upgradeToAndCall", ["address", "bytes"]),
        },
        {
            quorumId: TIMELOCKED_PROD_QUORUM_ID,
            target: staking,
            funcSelector: FunctionFragment.getSelector("upgradeToAndCall", ["address", "bytes"]),
        },
        {
            quorumId: TIMELOCKED_PROD_QUORUM_ID,
            target: minerMgr,
            funcSelector: FunctionFragment.getSelector("upgradeToAndCall", ["address", "bytes"]),
        }
    ]

    m.call(gateway, "setCallAuthLevels", [settings])

    // m.call(poc, "setAdmin", [gateway])
    // m.call(poc, "transferOwnership", [gateway])

    // SET FEEPERBYTE ON FEECONVERTERDIRECT

    return {
        gateway,
        ledgerMgr,
        poc,
        authMgr,
        feeConverterDirect,
        staking,
        minerMgr,
        nativeFeeRepo
    }
})

const configModule = buildModule("ConfigModule", (m) => {
    const { gateway,
        ledgerMgr,
        poc,
        authMgr,
        feeConverterDirect,
        staking,
        minerMgr,
        nativeFeeRepo
    } = m.useModule(deployModule)

    m.call(poc, "updateFeeTarget")
    m.call(gateway, "updateQpAddresses", [poc, ledgerMgr, staking])

    return {
        gateway,
        ledgerMgr,
        poc,
        authMgr,
        feeConverterDirect,
        staking,
        minerMgr,
        nativeFeeRepo
    }
})

export default configModule;
