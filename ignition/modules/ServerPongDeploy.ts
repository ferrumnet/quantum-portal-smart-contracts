import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"


const deployModule = buildModule("ServerPongModule", (m) => {    
    const serverPong = m.contract("ServerPong", ["0xD73B1C4D1e686492aa46F21e1701Fd7d707b53BA", 1000000000000000000n])
    return {serverPong}
})

export default deployModule;
