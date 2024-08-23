import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"


const deployModule = buildModule("ServerPongModule", (m) => {    
    const serverPong = m.contract("ServerPong", ["0xF348a3D83ab349efC622731DD64c8c3bA4543b25", 1000000000000000000n])
    return {serverPong}
})

export default deployModule;
