import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"


const deployModule = buildModule("FeeConverter", (m) => {
    const owner = m.getAccount(0)
    const feeConverterDirectImpl = m.contract("QuantumPortalFeeConverterDirectUpgradeable", [], { id: "FeeConverterDirectImpl"})
    const initializeCalldata = m.encodeFunctionCall(feeConverterDirectImpl, "initialize", [
        owner
    ]);
    const feeConverterDirectProxy = m.contract("ERC1967Proxy", [feeConverterDirectImpl, initializeCalldata], { id: "FeeConverterDirectProxy"})
    const feeConverter = m.contractAt("QuantumPortalFeeConverterDirectUpgradeable", feeConverterDirectProxy, { id: "FeeConverterDirect"})

    return {feeConverter}
})

export default deployModule;
