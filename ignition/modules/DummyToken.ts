import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"


const deployModule = buildModule("DummyTokenModule", (m) => {    
    const token = m.contract("TestToken2", [], { id: "TestToken"})
    return {token}
})

export default deployModule;
