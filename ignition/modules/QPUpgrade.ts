import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import deployModule from "./QPDeploy";
import { Wei } from 'foundry-contracts/dist/test/common/Utils';
import { ZeroAddress } from "ethers";
import { loadQpDeployConfig, QpDeployConfig } from "../../scripts/utils/DeployUtils";
const DEFAULT_QP_CONFIG_FILE = 'QpDeployConfig.yaml';


// Existing addresses
const GatewayAddress = "0xeC11d853f05e7174F43834AfCf31d52D6d01B552"
const FeeConverterDirectAddress = "0x70F20dEFb874122308A1b151ECFc035d6D4Fe74D"
const LedgerMgrAddress = "0xba8be144Ca01B11aBd457Bc4d93cC8F67a94984e"
const PocAddress = "0x7719ad3651a953cFe05379d293D5D3D580D0E359"
const AuthMgrAddress = "0xcd19D54Ab47394A454C2B247689a57c154488df3"
const StakingAddress = "0xE81d8000912780D1AF7A1d16Ab38A168d6aFBCC5"
const MinerMgrAddress = "0xc06422f1D2D59C0cb065bd8a35135b62bF6Cf015"
const TestTokenAddress = "0xd12e9329865B6423E39a2E4C3d58b7a1C52f3849"

// Upgrading ledgerMgr as example
const upgradeModule = buildModule("UpgradeModule", (m) => {
    
    // Upgrade Gateway
    // const newGatewayImpl = m.contract("QuantumPortalGatewayUpgradeable", [ZeroAddress], { id: "DeployNewGatewayImpl"})
    const gatewayProxy = m.contractAt("QuantumPortalGatewayUpgradeable", GatewayAddress, { id: "AttachGatewayProxy"})
    // m.call(gatewayProxy, "upgradeToAndCall", [newGatewayImpl, "0x"], { id: "UpgradeGateway"})
    const gateway = m.contractAt("QuantumPortalGatewayUpgradeable", gatewayProxy, { id: "NA1"})

    // Upgrade Poc
    // const newPocImpl = m.contract("QuantumPortalPocImplUpgradeable", [], { id: "DeployNewPocImpl"})
    // const pocProxy = m.contractAt("QuantumPortalPocImplUpgradeable", PocAddress, { id: "AttachPocProxy"})
    // m.call(gateway, "upgradeQpComponentAndCall", [pocProxy, newPocImpl, "0x"], { id: "UpgradePoc"})
    // const poc = m.contractAt("QuantumPortalPocImplUpgradeable", pocProxy, { id: "NA2"})

    // // Upgrade LedgerMgr
    // const newLedgerMgrImpl = m.contract("QuantumPortalLedgerMgrImplUpgradeable", [], { id: "DeployNewLedgerMgrImpl"})
    // const ledgerMgrProxy = m.contractAt("QuantumPortalLedgerMgrImplUpgradeable", LedgerMgrAddress, { id: "AttachLedgerMgrProxy"})
    // m.call(gateway, "upgradeQpComponentAndCall", [ledgerMgrProxy, newLedgerMgrImpl, "0x"], { id: "UpgradeLedgerMgr"})
    // const ledgerMgr = m.contractAt("QuantumPortalLedgerMgrImplUpgradeable", ledgerMgrProxy, { id: "NA3"})

    // Upgrade MinerMgr
    const newMinerMgrImpl = m.contract("QuantumPortalMinerMgrUpgradeable", [], { id: "DeployNewMinerMgrImpl"})
    const minerMgrProxy = m.contractAt("QuantumPortalMinerMgrUpgradeable", MinerMgrAddress, { id: "AttachMinerMgrProxy"})
    m.call(gateway, "upgradeQpComponentAndCall", [minerMgrProxy, newMinerMgrImpl, "0x"], { id: "UpgradeMinerMgr"})
    const minerMgr = m.contractAt("QuantumPortalMinerMgrUpgradeable", minerMgrProxy, { id: "NA4"})

    // Set portal

    return {gateway}
})

export default upgradeModule;
