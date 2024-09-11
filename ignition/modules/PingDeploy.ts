import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"


// Arb/bsc/base portal: 0xD73B1C4D1e686492aa46F21e1701Fd7d707b53BA
// ferrum portal: 0xF348a3D83ab349efC622731DD64c8c3bA4543b25

const deployModule = buildModule("DeployModule", (m) => {    
    const ping = m.contract("Ping", [
        "0xD73B1C4D1e686492aa46F21e1701Fd7d707b53BA", // Portal address
        1000000000000000000n
    ])


    m.call(ping, "updateRemotePeers", [[26100], ["0x93069da82B264E94068aA991b88b3478cf0861BE"]])

    return {ping}
})

export default deployModule;
