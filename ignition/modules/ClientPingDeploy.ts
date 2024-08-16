import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"


const deployModule = buildModule("ClientPingModule", (m) => {    
    const clientPing = m.contract("ClientPing", [
        "0x64947EBc33f8ED810D635e62525a0696C0a3717B", // Portal address
        8453,
        "0xe9EC8965932d86e751B60384D664cfbc09A9597D", // Server address
        1000000000000000000n
    ])
    return {clientPing}
})

export default deployModule;
