import hre, { ethers } from "hardhat"
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers"
import { expect } from "chai";
import { deployAll } from "./QuantumPortalUtils";


const GWEI = 1_000_000_000n
const ETH_FRM_PRICE = 120_000n
const BNB_FRM_PRICE = 30_000n
const CHAIN1_GAS_PRICE = 1n * GWEI / 10n
const CHAIN2_GAS_PRICE = 5n * GWEI
const MAINNET_GAS_PRICE = 20n * GWEI
const PAYLOAD_SIZE = 292n

describe("FeeConverter", function () {
    let ctx

    async function deploymentFixture() {
        ctx = await deployAll()
    }

    beforeEach("should deploy and config MultiSwap", async () => {
        await loadFixture(deploymentFixture)
        const chainIds = [ctx.chain1.chainId, ctx.chain2.chainId, 1]
        const chainNativeToFrmPrices = [BNB_FRM_PRICE, ETH_FRM_PRICE, ETH_FRM_PRICE]
        const chainGasPrices = [CHAIN1_GAS_PRICE, CHAIN2_GAS_PRICE, MAINNET_GAS_PRICE]
        const isL2 = [false, true, false]

        await ctx.chain1.feeConverter.setChainGasPrices(chainIds, chainNativeToFrmPrices, chainGasPrices, isL2)
    })

    it("Get fixed fee", async function () {
        // Fee per byte set to 0.001 FRM in deployAll()
        const feePerByte = ethers.parseEther("0.001")
        expect(await ctx.chain1.feeConverter.fixedFee(PAYLOAD_SIZE)).to.be.equal(PAYLOAD_SIZE * feePerByte)
    })

    it("Get target chain fee for tx execution", async function () {
        const gasLimit = 200000n
        const gasCostInTargetNative = gasLimit * CHAIN2_GAS_PRICE
        const gasCostInFrm = gasCostInTargetNative * ETH_FRM_PRICE
        const l1Cost = getl1Cost(PAYLOAD_SIZE)

        expect(await ctx.chain1.feeConverter.targetChainGasFee(ctx.chain2.chainId, gasLimit, PAYLOAD_SIZE)).to.be.equal(gasCostInFrm + l1Cost)
    })

    it("Get fixed fee in local chain native asset", async function () {
        const feePerByte = ethers.parseEther("0.001")
        const fixFeeInNative = PAYLOAD_SIZE * feePerByte / BNB_FRM_PRICE

        expect(await ctx.chain1.feeConverter.fixedFeeNative(PAYLOAD_SIZE)).to.be.equal(fixFeeInNative)
    })

    it("Get target chain fee for tx execution in local chain native asset", async function () {
        const gasLimit = 200000n
        const gasCostInTargetNative = gasLimit * CHAIN2_GAS_PRICE
        const gasCostInFrm = gasCostInTargetNative * ETH_FRM_PRICE
        const l1Cost = getl1Cost(PAYLOAD_SIZE)
        const gasCostInEth = (gasCostInFrm + l1Cost) / BNB_FRM_PRICE

        expect(await ctx.chain1.feeConverter.targetChainGasFeeNative(ctx.chain2.chainId, gasLimit, PAYLOAD_SIZE)).to.be.equal(gasCostInEth)
    })
})

function getl1Cost(size) {
    return (256n + size) * 16n * MAINNET_GAS_PRICE
}
