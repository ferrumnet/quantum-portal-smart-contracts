import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"


const deployModule = buildModule("ClientPingModule", (m) => {    
    const clientPing = m.contract("ClientPing", [
        "0x64947EBc33f8ED810D635e62525a0696C0a3717B", // Portal address
        42161,
        "0x714D338E30ab91C981691CE959a8589715A6A1aC", // Server address
        1000000000000000000n
    ])
    return {clientPing}
})

export default deployModule;
