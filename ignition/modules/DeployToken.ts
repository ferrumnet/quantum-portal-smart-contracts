import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"

const balanceHolder = "0x5Db36F5251485d22dD86Dabab5EC292ED42d4925"
const owner = "0xA4c66909e78132D4159465e19Ad5fE2c8a176137"

const deployModule = buildModule("TokenModule", (m) => {    
    // const _owner = m.getAccount(0)
    // console.log("Owner:", _owner)
    // if (owner.toLocaleLowerCase() !== _owner.toString().toLocaleLowerCase()) {
    //     throw new Error("Owner mismatch")
    // }

    const tokenImpl = m.contract("QpFerrumTokenUpgradeable", [], { id: "TokenImpl"})
    const initializeCalldata = m.encodeFunctionCall(tokenImpl, "initialize", [
        owner,
        balanceHolder
    ]);
    const tokenProxy = m.contract("ERC1967Proxy", [tokenImpl, initializeCalldata], { id: "TokenProxy"})
    const token = m.contractAt("QpFerrumTokenUpgradeable", tokenProxy, { id: "Token"})
    return {token}
})

export default deployModule;

