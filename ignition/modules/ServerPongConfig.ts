import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import serverDeployModule from "./ServerPongDeploy"


const deployModule = buildModule("ServerPongConfigModule", (m) => {
    const { serverPong } = m.useModule(serverDeployModule)
    m.call(serverPong, "updateRemotePeers", [
        [42161, 8453, 56], // chainIds,
        ["0x2Df204F847ca062624E34bB073dAe0c96da444ea", "0x2Df204F847ca062624E34bB073dAe0c96da444ea", "0x2Df204F847ca062624E34bB073dAe0c96da444ea"], // clientAddresses,
    ])
    return { serverPong }
})

export default deployModule;
