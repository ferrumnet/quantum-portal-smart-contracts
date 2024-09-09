import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"


// Existing addresses
const GatewayAddress = "0x01072085B62F3572e034798F3FCa46CBE6D581d3"
const PocAddress = "0xF348a3D83ab349efC622731DD64c8c3bA4543b25"
const LedgerMgrAddress = "0x2381E4d8fB6fD92cAF233B2eDa8f70beaDF2932f"
const MinerMgrAddress = "0xAa78a2c6E78c315f7a4068120637205F17c5ae92"
const AuthMgrAddress = "0x2927ec4185210FA20cf5d86B84B16E8fE064fF97"
const FeeConverterDirectAddress = "0x8de74628Cb797f82B7FBc0d44C4D0c8DBeE4B7d1"
const StakingAddress = "0x19e2a97a0afEa7DC2969d187d79355F5454e4023"
const TestTokenAddress = "0xd12e9329865B6423E39a2E4C3d58b7a1C52f3849"

// Upgrading ledgerMgr as example
const upgradeModule = buildModule("UpgradeModule", (m) => {
    
    // Upgrade Gateway
    // const newGatewayImpl = m.contract("QuantumPortalGatewayUpgradeable", [ZeroAddress], { id: "DeployNewGatewayImpl"})
    const gatewayProxy = m.contractAt("QuantumPortalGatewayUpgradeable", GatewayAddress, { id: "AttachGatewayProxy"})
    // m.call(gatewayProxy, "upgradeToAndCall", [newGatewayImpl, "0x"], { id: "UpgradeGateway"})
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

    // Upgrade MinerMgr
    const newMinerMgrImpl = m.contract("QuantumPortalMinerMgrUpgradeable", [], { id: "DeployNewMinerMgrImpl"})
    const minerMgrProxy = m.contractAt("QuantumPortalMinerMgrUpgradeable", MinerMgrAddress, { id: "AttachMinerMgrProxy"})
    m.call(gateway, "upgradeQpComponentAndCall", [minerMgrProxy, newMinerMgrImpl, "0x"], { id: "UpgradeMinerMgr"})
    const minerMgr = m.contractAt("QuantumPortalMinerMgrUpgradeable", minerMgrProxy, { id: "NA4"})

    // Upgrade AuthMgr
    const newAuthMgrImpl = m.contract("QuantumPortalAuthorityMgrUpgradeable", [], { id: "DeployNewAuthMgrImpl"})
    const authMgrProxy = m.contractAt("QuantumPortalAuthorityMgrUpgradeable", AuthMgrAddress, { id: "AttachAuthMgrProxy"})
    m.call(gateway, "upgradeQpComponentAndCall", [authMgrProxy, newAuthMgrImpl, "0x"], { id: "UpgradeAuthMgr"})
    const authMgr = m.contractAt("QuantumPortalAuthorityMgrUpgradeable", authMgrProxy, { id: "NA5"})

    // Upgrade FeeConverterDirect
    const newFeeConverterDirectImpl = m.contract("QuantumPortalFeeConverterDirectUpgradeable", [], { id: "DeployNewFeeConverterDirectImpl"})
    const feeConverterDirectProxy = m.contractAt("QuantumPortalFeeConverterDirectUpgradeable", FeeConverterDirectAddress, { id: "AttachFeeConverterDirectProxy"})
    m.call(gateway, "upgradeQpComponentAndCall", [feeConverterDirectProxy, newFeeConverterDirectImpl, "0x"], { id: "UpgradeFeeConverterDirect"})
    const feeConverterDirect = m.contractAt("QuantumPortalFeeConverterDirectUpgradeable", feeConverterDirectProxy, { id: "NA6"})

    // Upgrade Staking
    const newStakingImpl = m.contract("QuantumPortalStakeWithDelegateUpgradeable", [], { id: "DeployNewStakingImpl"})
    const stakingProxy = m.contractAt("QuantumPortalStakeWithDelegateUpgradeable", StakingAddress, { id: "AttachStakingProxy"})
    m.call(gateway, "upgradeQpComponentAndCall", [stakingProxy, newStakingImpl, "0x"], { id: "UpgradeStaking"})
    const staking = m.contractAt("QuantumPortalStakeWithDelegateUpgradeable", stakingProxy, { id: "NA7"})

    return {gateway}
})

export default upgradeModule;