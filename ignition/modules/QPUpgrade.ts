import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import deployModule from "./QPDeploy";
import { Wei } from 'foundry-contracts/dist/test/common/Utils';
import { ZeroAddress } from "ethers";
import { loadQpDeployConfig, QpDeployConfig } from "../../scripts/utils/DeployUtils";
const DEFAULT_QP_CONFIG_FILE = 'QpDeployConfig.yaml';


// Upgrading ledgerMgr as example
const upgradeModule = buildModule("UpgradeModule", (m) => {
    // Ignition will reconcile deployments in ignition/deployments folder, so won't deploy again
    const {gateway, ledgerMgr} = m.useModule(deployModule)
    const ledgerMgrImpl = m.contract("QuantumPortalLedgerMgrImplUpgradeableV2", [], { id: "LedgerMgrImpl"})

    m.call(gateway, "upgradeQpComponentAndCall", [ledgerMgr, ledgerMgrImpl, "0x"])

    return {ledgerMgr}
})

export default upgradeModule;
