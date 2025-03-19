import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"

// Existing addresses
const PocAddress = "0xA45baceEB0C6B072B17EF6483E4fb50a49dC5F4b"
const LedgerMgrAddress = "0x50eE60c1626ef57AD6a61f82D13Fea919B1eE545"
// const MinerMgrAddress = "0x7532302523dcafa33F6fb9b35C935ac8918d968a"
// const AuthMgrAddress = "0x0d2336B388Eb53EC034acD4e27C9A5556EEda840"
const StakingAddress = "0xA862E218abEC264c4Fb41671F6905a54Bc853354" // Ferrum
// const GatewayAddress = "0xAca0E5235Fc2b8C00fD7BCa8880AAd9234aB264D"
const NativeFeeRepoAddress = "0x3068B699AF7D7319fd788f2bb558f2F09C070CF2"
const FeeConverterAddress = "0x53a2b5573fd35a62b23eD8a1984f7788E70B8981"

// Upgrading ledgerMgr as example
const updateNativeFeeRepoModule = buildModule("UpgradeNativeFeeRepo", (m) => {

    const owner = m.getAccount(0)

    // Upgrade NativeFeeRepo
    // const pocImpl = m.contract("QuantumPortalPocImplUpgradeable", [], { id: "newPocImpl"})
    // const ledgerMgrImpl = m.contract("QuantumPortalLedgerMgrImplUpgradeable", [], { id: "newLedgerMgrImpl_"})
    const stakeImpl = m.contract("QuantumPortalStakeWithDelegateUpgradeable", [], { id: "newStakeImpl_3"})
    const stakeProxy = m.contractAt("QuantumPortalStakeWithDelegateUpgradeable", StakingAddress, { id: "stakeProxy"})
    // const nativeFeeRepoImpl = m.contract("QuantumPortalNativeFeeRepoBasicUpgradeable", [], { id: "DeployNewNativeFeeRepoImpl"})
    // const nativeFeeRepo = m.contractAt("QuantumPortalNativeFeeRepoBasicUpgradeable", NatifeFeeRepoAddress, { id: "DeployNewNativeFeeRepoProxy"})
    // const initializeCalldata = m.encodeFunctionCall(nativeFeeRepoImpl, "initialize", [
    //     PocAddress,
    //     FeeConverterAddress,
    //     owner,
    //     owner
    // ]);
    // const pocProxy = m.contract("ERC1967Proxy", [nativeFeeRepoImpl, initializeCalldata], { id: "NewNativeFeeRepoProxy"})
    // const pocProxy = m.contractAt("QuantumPortalPocImplUpgradeable", PocAddress, { id: "newPocProxy"})
    // const ledgerMgrProxy = m.contractAt("QuantumPortalLedgerMgrUpgradeable", LedgerMgrAddress, { id: "newLedgerMgrProxy"})
    // const nativeFeeRepoProxy = m.contractAt("ERC1967Proxy", NativeFeeRepoAddress, { id: "NativeFeeRepoProxy"})

    // const nativeFeeRepo = m.contractAt("QuantumPortalNativeFeeRepoBasicUpgradeable", NativeFeeRepoAddress, { id: "DeployNewNativeFeeRepoProxy"})
    
    
    // m.call(pocProxy, "upgradeToAndCall", [pocImpl, '0x'], { id: "newPocUpgradeToAndCall"})
    // m.call(ledgerMgrProxy, "upgradeToAndCall", [ledgerMgrImpl, '0x'], { id: "newLedgerMgrUpgradeToAndCall"})

    // Setting verifyer to lock mining...
    m.call(stakeProxy, "upgradeToAndCall", [stakeImpl, '0x'], { id: "newStakeUpgradeToAndCall_3"})
    // m.call(stakeImpl, "updateStakeVerifyer", [owner], { id: "newStakeVerifyer_"})

    // setNativeFeeRepo on Poc
    // const poc = m.contractAt("QuantumPortalPocImplUpgradeable", PocAddress, { id: "Poc"})
    // m.call(pocP, "setNativeFeeRepo", [nativeFeeRepo], { id: "SetNewNativeFeeRepo"})

    return {stakeProxy}
})

export default updateNativeFeeRepoModule;

