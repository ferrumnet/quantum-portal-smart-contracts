import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import serverDeployModule from "./ServerPongDeploy"


const deployModule = buildModule("ServerPongConfigModule", (m) => {
    const { serverPong } = m.useModule(serverDeployModule)
    m.call(serverPong, "updateRemotePeers", [
        [42161], // chainIds,
        ["0x6e6D2F5bc91aa8432F848278034FD81dD56e3Db6"], // clientAddresses,
    ])
    return { serverPong }
})

export default deployModule;
