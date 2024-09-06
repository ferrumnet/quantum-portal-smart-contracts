import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"


// Existing addresses
const GatewayAddress = "0x01072085B62F3572e034798F3FCa46CBE6D581d3"
const LedgerMgrAddress = "0x2381E4d8fB6fD92cAF233B2eDa8f70beaDF2932f"

// Upgrading ledgerMgr as example
const upgradeModule = buildModule("UpgradeModule", (m) => {
    
    // Get gateway
    const gateway = m.contractAt("QuantumPortalGatewayUpgradeable", GatewayAddress)

    // Upgrade MinerMgr
    const authMgrImpl = m.contract("QuantumPortalLedgerMgrImplUpgradeable", [])
    m.call(gateway, "upgradeQpComponentAndCall", [LedgerMgrAddress, authMgrImpl, "0x"])

    return {gateway}
})

export default upgradeModule;
