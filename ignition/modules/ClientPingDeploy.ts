import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"


const deployModule = buildModule("ClientPingModule", (m) => {    
    const clientPing = m.contract("ClientPing", [
        "0xD73B1C4D1e686492aa46F21e1701Fd7d707b53BA", // Portal address
        26100, // Server chain Id
        "0xF6540DDa789D9E2058B8AEeBf53e80C537689fc6", // Server address
        1000000000000000000n
    ])
    return {clientPing}
})

export default deployModule;
