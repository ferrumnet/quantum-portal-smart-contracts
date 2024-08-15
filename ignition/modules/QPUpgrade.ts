import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import deployModule from "./QPDeploy";
import { Wei } from 'foundry-contracts/dist/test/common/Utils';
import { ZeroAddress } from "ethers";
import { loadQpDeployConfig, QpDeployConfig } from "../../scripts/utils/DeployUtils";
const DEFAULT_QP_CONFIG_FILE = 'QpDeployConfig.yaml';


// Existing addresses
const GatewayAddress = "0xeC11d853f05e7174F43834AfCf31d52D6d01B552"
const FeeConverterDirectAddress = "0xee36fBfc9A12DAa26fa79947b3AFdF81226CE8a4"
const LedgerMgrAddress = "0xba8be144Ca01B11aBd457Bc4d93cC8F67a94984e"
const PocAddress = "0x7719ad3651a953cFe05379d293D5D3D580D0E359"
const AuthMgrAddress = "0x770f21B2434D7c19Ff975700F3303eBdeF2fE47a"
const StakingAddress = "0x023007509555e5e478081FB80Fc7594bbc381Fa6"
const MinerMgrAddress = "0x497ad20ada48310b66EEa9C1fD656DBf8eD33B6e"
const TestTokenAddress = "0xd12e9329865B6423E39a2E4C3d58b7a1C52f3849"

// Upgrading ledgerMgr as example
const upgradeModule = buildModule("UpgradeModule", (m) => {
    
    // Upgrade Gateway
    const newGatewayImpl = m.contract("QuantumPortalGatewayUpgradeable", [ZeroAddress], { id: "DeployNewGatewayImpl"})
    const gatewayProxy = m.contractAt("QuantumPortalGatewayUpgradeable", GatewayAddress, { id: "AttachGatewayProxy"})
    m.call(gatewayProxy, "upgradeToAndCall", [newGatewayImpl, "0x"], { id: "UpgradeGateway"})
    const gateway = m.contractAt("QuantumPortalGatewayUpgradeable", gatewayProxy, { id: "NA1"})

    // Upgrade Poc
    const newPocImpl = m.contract("QuantumPortalPocImplUpgradeable", [], { id: "DeployNewPocImpl"})
    const pocProxy = m.contractAt("QuantumPortalPocImplUpgradeable", PocAddress, { id: "AttachPocProxy"})
    m.call(gateway, "upgradeQpComponentAndCall", [pocProxy, newPocImpl, "0x"], { id: "UpgradePoc"})
    const poc = m.contractAt("QuantumPortalPocImplUpgradeable", pocProxy, { id: "NA2"})

    // Upgrade LedgerMgr
    const newLedgerMgrImpl = m.contract("QuantumPortalLedgerMgrImplUpgradeable", [], { id: "DeployNewLedgerMgrImpl"})
    const ledgerMgrProxy = m.contractAt("QuantumPortalLedgerMgrImplUpgradeable", LedgerMgrAddress, { id: "AttachLedgerMgrProxy"})
    m.call(gateway, "upgradeQpComponentAndCall", [ledgerMgrProxy, newLedgerMgrImpl, "0x"], { id: "UpgradeLedgerMgr"})
    const ledgerMgr = m.contractAt("QuantumPortalLedgerMgrImplUpgradeable", ledgerMgrProxy, { id: "NA3"})

    return {gateway, poc, ledgerMgr}
})

export default upgradeModule;
