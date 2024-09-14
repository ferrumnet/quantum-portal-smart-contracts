import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import { ZeroAddress } from "ethers";


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
    const newGatewayImpl = m.contract("QuantumPortalGatewayUpgradeable", ["0x0000000000000000000000000000000000000802"], { id: "DeployNewGatewayImpl"})
    const gatewayProxy = m.contractAt("QuantumPortalGatewayUpgradeable", GatewayAddress, { id: "AttachGatewayProxy"})
    m.call(gatewayProxy, "upgradeToAndCall", [newGatewayImpl, "0x"], { id: "UpgradeGateway"})
    const gateway = m.contractAt("QuantumPortalGatewayUpgradeable", gatewayProxy, { id: "NA1"})

    // Upgrade StakeWithDelegate
    const newStakeWithDelegateImpl = m.contract("QuantumPortalStakeWithDelegateUpgradeable", [], { id: "DeployNewStakeWithDelegateImpl"})
    const stakeWithDelegateProxy = m.contractAt("QuantumPortalStakeWithDelegateUpgradeable", StakingAddress, { id: "AttachStakeWithDelegateProxy"})
    const initializeCalldata = m.encodeFunctionCall(stakeWithDelegateProxy, "initialize(address,address,address,address,address)", [
        "0x0000000000000000000000000000000000000802",
        AuthMgrAddress,
        ZeroAddress,
        gateway,
        "0xdCd60Be5b153d1884e1E6E8C23145D6f3546315e"
    ]);
    
    m.call(gateway, "upgradeQpComponentAndCall", [stakeWithDelegateProxy, newStakeWithDelegateImpl, initializeCalldata], { id: "UpgradeStakeWithDelegate"})

    // Upgrade token on portal
    const pocProxy = m.contractAt("QuantumPortalPocImplUpgradeable", PocAddress, { id: "AttachPocProxy"})

    const minerMgrr = m.contractAt("QuantumPortalMinerMgrUpgradeable", MinerMgrAddress, { id: "AttachMinerMgrProxy"})

    m.call(pocProxy, "setFeeToken", ["0x0000000000000000000000000000000000000802"])
    
	m.call(minerMgrr, "updateBaseToken", ["0x0000000000000000000000000000000000000802"])

    return {gateway}
})

export default upgradeModule;
