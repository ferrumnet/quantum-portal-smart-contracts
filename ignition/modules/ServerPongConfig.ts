import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import serverDeployModule from "./ServerPongDeploy"


const deployModule = buildModule("ServerPongConfigModule", (m) => {
    const { serverPong } = m.useModule(serverDeployModule)
    m.call(serverPong, "updateRemotePeers", [
        [26100], // chainIds,
        ["0x2e2A7ADe98d17Fe726f0362f78fD5d4718FF5FCC"], // clientAddresses,
    ])
    return { serverPong }
})

export default deployModule;
