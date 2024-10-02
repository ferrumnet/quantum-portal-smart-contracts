import hre, { ethers } from "hardhat"
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers"
import FeeConverterDeployModule from "../../../ignition/modules/test/FeeConverter"

const GWEI = 1_000_000_000n
const FRM_PRICE = 125_000n

describe("FeeConverter", function () {
    let feeConverter
    async function deploymentFixture() {
        ({ feeConverter } = await hre.ignition.deploy(FeeConverterDeployModule))
    }

    beforeEach("should deploy and config MultiSwap", async () => {
        await loadFixture(deploymentFixture)
        await feeConverter.updateFeePerByteX128(ethers.parseEther("1"))
        await feeConverter.setChainGasPricesX128([31337], [FRM_PRICE], [2n * GWEI])     
    })

    it("check target chain fixed fee", async function () {
        console.log(await feeConverter.targetChainFixedFee(31337, 292))
    })

    it("check target chain gas price", async function () {
        // TODO Check:
        // Assume:
        // Chain with ETH as native. Gas price of 2 gwei.
        // ~0.02USD per FRM. $2500 ETH. So 125000 FRM per ETH
        // 200000 gas tx cost on target chain in ETH = 200000 * 2 gwei = 0.0004 ETH
        // 0.0004 ETH * 125000 FRM = 50 FRM for tx gas cost

        console.log(await feeConverter.targetChainGasFee(31337, 200000))
    })
})
