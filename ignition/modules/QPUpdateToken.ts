import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import { ZeroAddress } from "ethers"


// Existing addresses
const PocAddress = "0x93E5f898163e2708d57a02b7532802DE31CEa708"
const MinerMgrAddress = "0x7532302523dcafa33F6fb9b35C935ac8918d968a"
const AuthMgrAddress = "0x0d2336B388Eb53EC034acD4e27C9A5556EEda840"
const StakingAddress = "0x486d007c274064435cc7a6906b6AfB1D153E3932"
const GatewayAddress = "0xAca0E5235Fc2b8C00fD7BCa8880AAd9234aB264D"

// Upgrading ledgerMgr as example
const updateTokenModule = buildModule("UpdateToken", (m) => {

    const owner = m.getAccount(0)
    const newTokenAddress = "0x4Add1001B24A2Ee1417F02d3C18Bdad0d6fbC59e"

    // Upgrade Staking
    const newStakingImpl = m.contract("QuantumPortalStakeWithDelegateUpgradeable", [], { id: "DeployNewStakingImpl"})
    const staking = m.contractAt("QuantumPortalStakeWithDelegateUpgradeable", StakingAddress, { id: "AttachStakingProxy"})
    
    const initializeCalldata = m.encodeFunctionCall(newStakingImpl, "initialize(address,address,address,address)", [
        newTokenAddress,
        AuthMgrAddress,
        ZeroAddress,
        owner
    ]);
    
    m.call(staking, "upgradeToAndCall", [newStakingImpl, initializeCalldata], { id: "UpgradeStaking"})

    // SetFeeToken on Poc
    const poc = m.contractAt("QuantumPortalPocImplUpgradeable", PocAddress)
    m.call(poc, "setFeeToken", [newTokenAddress])

    // UpdateBaseToken on MinerMgr
    const minerMgr = m.contractAt("QuantumPortalMinerMgrUpgradeable", MinerMgrAddress)
    m.call(minerMgr, "updateBaseToken", [newTokenAddress])

    return {staking}
})

const setAdminModule = buildModule("SetAdmin", (m) => {
    const {staking} = m.useModule(updateTokenModule)
    m.call(staking, "setAdmin", [GatewayAddress])

    return {staking}
})

export default setAdminModule;
