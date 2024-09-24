import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"


const deployModule = buildModule("DummyTokenModule", (m) => {    
    const token = m.contract("TestToken", [], { id: "TestToken"})
    return {token}
})

export default deployModule;
