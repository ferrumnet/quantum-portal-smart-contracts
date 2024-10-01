import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import { ZeroAddress } from "ethers"


// Existing addresses
const newAdmin = "0x17C5B49A55466Ff60ca4e6Dfd40d5a0F40ac137a"
const qpContractAddress = "0x7621c803B6553dF43EF03D5e3736A0A36459BbcA"


const upgradeModule = buildModule("SetAdmin", (m) => {
    const qpContract = m.contractAt("WithAdmin", qpContractAddress, { id: "AttachContract"})    
    m.call(qpContract, "setAdmin", [newAdmin], { id: "setAdmin"})

    return {qpContract}
})

export default upgradeModule;
