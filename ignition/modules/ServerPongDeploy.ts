import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"


const deployModule = buildModule("ServerPongModule", (m) => {    
    const serverPong = m.contract("ServerPong", ["0x64947EBc33f8ED810D635e62525a0696C0a3717B", 1000000000000000000n])
    return {serverPong}
})

export default deployModule;
