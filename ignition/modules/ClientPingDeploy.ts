import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"


const deployModule = buildModule("ClientPingModule", (m) => {    
    const clientPing = m.contract("ClientPing", [
        "0xd6BCe4677a9F00f85AF02dD5D19EA52fF14EDd05", // Portal address
        26100, // Server chain Id
        "0xdf721686ceD9B90C904572151a10aCD78468355b", // Server address
        10000000000000000n
    ])
    return {clientPing}
})

export default deployModule;
