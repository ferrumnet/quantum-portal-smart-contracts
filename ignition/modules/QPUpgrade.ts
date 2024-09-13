import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import { ZeroAddress } from "ethers"


// Existing addresses
const GatewayAddress = "0xBa084017c14c81B9bb07C7730176307cbb264763"
const PocAddress = "0xD73B1C4D1e686492aa46F21e1701Fd7d707b53BA"
const LedgerMgrAddress = "0x0f7afAaea1618b46b8c2c6e04250Bad785BE8E47"
const MinerMgrAddress = "0xDf77791F9682d7984B4Dbbf3E6ae70646FA222a9"
const AuthMgrAddress = "0x291eD535F53D0B38515dEC8c6556d7A840c2D95B"
const FeeConverterDirectAddress = "0xf8fD482B3d998D20C8562EE12BA5a94e610aBc38"
const StakingAddress = "0x19e2a97a0afEa7DC2969d187d79355F5454e4023"
const TestTokenAddress = "0x6D34420DcAf516bEc9D81e5d79FAC2100058C9AC"

// Upgrading ledgerMgr as example
const upgradeModule = buildModule("UpgradeModule", (m) => {
    
    // Upgrade Gateway
    // const newGatewayImpl = m.contract("QuantumPortalGatewayUpgradeable", [ZeroAddress], { id: "DeployNewGatewayImpl"})
    // const gatewayProxy = m.contractAt("QuantumPortalGatewayUpgradeable", GatewayAddress, { id: "AttachGatewayProxy"})
    // let initializeCalldata: any = m.encodeFunctionCall(newGatewayImpl, "initialize");
    // m.call(gatewayProxy, "upgradeToAndCall", [newGatewayImpl, initializeCalldata], { id: "UpgradeGateway"})
    // const gateway = m.contractAt("QuantumPortalGatewayUpgradeable", gatewayProxy, { id: "NA1"})
    
    // Upgrade Poc
    // const newPocImpl = m.contract("QuantumPortalPocImplUpgradeable", [], { id: "DeployNewPocImpl"})
    // const pocProxy = m.contractAt("QuantumPortalPocImplUpgradeable", PocAddress, { id: "AttachPocProxy"})
    // m.call(gateway, "upgradeQpComponentAndCall", [pocProxy, newPocImpl, "0x"], { id: "UpgradePoc"})
    // const poc = m.contractAt("QuantumPortalPocImplUpgradeable", pocProxy, { id: "NA2"})

    // Upgrade LedgerMgr
    // const newLedgerMgrImpl = m.contract("QuantumPortalLedgerMgrImplUpgradeable", [], { id: "DeployNewLedgerMgrImpl"})
    // const ledgerMgrProxy = m.contractAt("QuantumPortalLedgerMgrImplUpgradeable", LedgerMgrAddress, { id: "AttachLedgerMgrProxy"})
    // let initializeCalldata: any = m.encodeFunctionCall(newLedgerMgrImpl, "initialize");
    // m.call(ledgerMgrProxy, "upgradeToAndCall", [newLedgerMgrImpl, initializeCalldata], { id: "UpgradeLedgerMgr"})
    // const ledgerMgr = m.contractAt("QuantumPortalLedgerMgrImplUpgradeable", ledgerMgrProxy, { id: "NA3"})

    // Upgrade MinerMgr
    const newMinerMgrImpl = m.contract("QuantumPortalMinerMgrUpgradeable", [], { id: "DeployNewMinerMgrImpl"})
    const minerMgrProxy = m.contractAt("QuantumPortalMinerMgrUpgradeable", MinerMgrAddress, { id: "AttachMinerMgrProxy"})
    let initializeCalldata:any = m.encodeFunctionCall(newMinerMgrImpl, "initialize()");
    m.call(minerMgrProxy, "upgradeToAndCall", [newMinerMgrImpl, initializeCalldata], { id: "UpgradeMinerMgr"})
    const minerMgr = m.contractAt("QuantumPortalMinerMgrUpgradeable", minerMgrProxy, { id: "NA4"})

    // Upgrade AuthMgr
    const newAuthMgrImpl = m.contract("QuantumPortalAuthorityMgrUpgradeable", [], { id: "DeployNewAuthMgrImpl"})
    const authMgrProxy = m.contractAt("QuantumPortalAuthorityMgrUpgradeable", AuthMgrAddress, { id: "AttachAuthMgrProxy"})
    initializeCalldata = m.encodeFunctionCall(newAuthMgrImpl, "initialize");
    m.call(authMgrProxy, "upgradeToAndCall", [newAuthMgrImpl, initializeCalldata], { id: "UpgradeAuthMgr"})
    const authMgr = m.contractAt("QuantumPortalAuthorityMgrUpgradeable", authMgrProxy, { id: "NA5"})

    // Upgrade FeeConverterDirect
    // const newFeeConverterDirectImpl = m.contract("QuantumPortalFeeConverterDirectUpgradeable", [], { id: "DeployNewFeeConverterDirectImpl"})
    // const feeConverterDirectProxy = m.contractAt("QuantumPortalFeeConverterDirectUpgradeable", FeeConverterDirectAddress, { id: "AttachFeeConverterDirectProxy"})
    // m.call(gateway, "upgradeQpComponentAndCall", [feeConverterDirectProxy, newFeeConverterDirectImpl, "0x"], { id: "UpgradeFeeConverterDirect"})
    // const feeConverterDirect = m.contractAt("QuantumPortalFeeConverterDirectUpgradeable", feeConverterDirectProxy, { id: "NA6"})

    // Upgrade Staking
    // const newStakingImpl = m.contract("QuantumPortalStakeWithDelegateUpgradeable", [], { id: "DeployNewStakingImpl"})
    // const stakingProxy = m.contractAt("QuantumPortalStakeWithDelegateUpgradeable", StakingAddress, { id: "AttachStakingProxy"})
    // m.call(gateway, "upgradeQpComponentAndCall", [stakingProxy, newStakingImpl, "0x"], { id: "UpgradeStaking"})
    // const staking = m.contractAt("QuantumPortalStakeWithDelegateUpgradeable", stakingProxy, { id: "NA7"})

    return {minerMgr}
})

export default upgradeModule;