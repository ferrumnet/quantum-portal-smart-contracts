import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import { ZeroAddress } from "ethers"


// Existing addresses testnet
// const GatewayAddress = "0xAca0E5235Fc2b8C00fD7BCa8880AAd9234aB264D"
// const PocAddress = "0x93E5f898163e2708d57a02b7532802DE31CEa708"
// const LedgerMgrAddress = "0x3e9316b40Bc5e676521B1DA04F4a8dF342E76FcB"
// const MinerMgrAddress = "0x7532302523dcafa33F6fb9b35C935ac8918d968a"
// const AuthMgrAddress = "0x0d2336B388Eb53EC034acD4e27C9A5556EEda840"
// const FeeConverterDirectAddress = "0x71683589f210E6254121E6704D7cc1D829ee6631"
// const StakingAddress = "0x486d007c274064435cc7a6906b6AfB1D153E3932"
// const NativeFeeRepoAddress = "0x140c01076488f679A324A2C5D17d50b45E88CaE7"
// const TestTokenAddress = "0x6D34420DcAf516bEc9D81e5d79FAC2100058C9AC"

// Existing addresses mainnet
const GatewayAddress = "0x256d45a60c2491078958E0432581377EC37b4184"
const PocAddress = "0xd6BCe4677a9F00f85AF02dD5D19EA52fF14EDd05"
const LedgerMgrAddress = "0xf37b8BA9Ba47ab13c32cC745F557b1F7A5cf822C"
const MinerMgrAddress = "0x33dB9377f88b9231A6407E84A3F55EC0460c0238"
const AuthMgrAddress = "0x59b7f3f25822c33aAff53CDafcA2929aCadB53FE"
const FeeConverterDirectAddress = "0x7621c803B6553dF43EF03D5e3736A0A36459BbcA"
const StakingAddress = "0x403032EcC2bD4B881f8871341a7b56b1Bd32eb68"
const NativeFeeRepoAddress = "0xEC33d2A4603a81485c46a53EA4D7d47A8647d330"


const upgradeModule = buildModule("Upgrade", (m) => {

    const owner = m.getAccount(0)
    
    //---------------- NativeFeeRepo -------------//
    const nativeFeeRepoImpl = m.contract("QuantumPortalNativeFeeRepoBasicUpgradeable", [], { id: "NativeFeeRepoImpl"})

    let initializeCalldata = m.encodeFunctionCall(nativeFeeRepoImpl, "initialize", [
        PocAddress,
        FeeConverterDirectAddress,
        owner,
        owner
    ])
    const nativeFeeRepoProxy = m.contract("ERC1967Proxy", [nativeFeeRepoImpl, initializeCalldata], { id: "NativeFeeRepoProxy"})
    const nativeFeeRepo = m.contractAt("QuantumPortalNativeFeeRepoBasicUpgradeable", nativeFeeRepoProxy, { id: "NativeFeeRepo"})

    const poc = m.contractAt("QuantumPortalPocImplUpgradeable", PocAddress, { id: "Poc"})

    m.call(poc, "setNativeFeeRepo", [nativeFeeRepo])

    return {nativeFeeRepo}
})

export default upgradeModule;
