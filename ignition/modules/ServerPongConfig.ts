import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import serverDeployModule from "./ServerPongDeploy"


const deployModule = buildModule("ServerPongConfigModule", (m) => {
    const { serverPong } = m.useModule(serverDeployModule)
    m.call(serverPong, "updateRemotePeers", [
        [42161, 8453, 56], // chainIds,
        ["0xC0F4b335a8D43869c5790baac58Dff546f8915eB", "0xC0F4b335a8D43869c5790baac58Dff546f8915eB", "0xC0F4b335a8D43869c5790baac58Dff546f8915eB"], // clientAddresses,
    ])
    return { serverPong }
})

export default deployModule;
