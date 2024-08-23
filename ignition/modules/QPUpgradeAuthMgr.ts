import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"


// Existing addresses
const GatewayAddress = "0x01072085B62F3572e034798F3FCa46CBE6D581d3"
const AuthMgrAddress = "0x2927ec4185210FA20cf5d86B84B16E8fE064fF97"

// Upgrading ledgerMgr as example
const upgradeModule = buildModule("UpgradeModule", (m) => {
    
    // Get gateway
    const gateway = m.contractAt("QuantumPortalGatewayUpgradeable", GatewayAddress)

    // Upgrade MinerMgr
    const authMgrImpl = m.contract("QuantumPortalAuthorityMgrUpgradeable", [])
    m.call(gateway, "upgradeQpComponentAndCall", [AuthMgrAddress, authMgrImpl, "0x"])

    return {gateway}
})

export default upgradeModule;
