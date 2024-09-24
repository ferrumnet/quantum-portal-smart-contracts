import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"


const deployModule = buildModule("ClientPingModule", (m) => {    
    const clientPing = m.contract("ClientPing", [
        "0xF348a3D83ab349efC622731DD64c8c3bA4543b25", // Portal address
        42161, // Server chain Id
        "0x49D2498464A27F4B5BC2aE72298CDE17a276598E", // Server address
        1000000000000000000n
    ])
    return {clientPing}
})

export default deployModule;
