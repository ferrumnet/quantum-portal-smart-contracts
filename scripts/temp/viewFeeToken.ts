import hre from "hardhat"
import { QuantumPortalFeeConverterDirectUpgradeable, QuantumPortalLedgerMgrUpgradeable, QuantumPortalNativeFeeRepoUpgradeable, QuantumPortalPocUpgradeable, QuantumPortalWorkPoolServerUpgradeable } from "../../typechain-types"
import { Wei } from "foundry-contracts/dist/test/common/Utils"

async function main() {
    const _mgr = '0x50eE60c1626ef57AD6a61f82D13Fea919B1eE545'

    const mgrF = await hre.ethers.getContractAt("QuantumPortalLedgerMgrUpgradeable", _mgr)
    const mgr = mgrF.attach(_mgr) as QuantumPortalLedgerMgrUpgradeable

    const feeConverter = await mgr.feeConvertor()
    const feeConvF = await hre.ethers.getContractAt("QuantumPortalFeeConverterDirectUpgradeable", feeConverter)
    const feeConv = feeConvF.attach(feeConverter) as QuantumPortalFeeConverterDirectUpgradeable

    const fee = await feeConv.fixedFee(9*32 + 100);
    console.log('FEE IS', fee.toString(), Wei.to(fee.toString()))

    const feeNative = await feeConv.fixedFeeNative(9*32 + 100);
    console.log('FEE NATIVE IS', feeNative.toString(), Wei.to(feeNative.toString()))

    console.log('Gettint minermgr baseToken')
    const minerMgrAddress = await mgr.minerMgr()
    console.log('Miner mgr address is', minerMgrAddress)
    const minerMgrF = await hre.ethers.getContractAt("QuantumPortalWorkPoolServerUpgradeable", minerMgrAddress)
    const minerMgr = minerMgrF.attach(minerMgrAddress) as QuantumPortalWorkPoolServerUpgradeable
    const baseToken = await minerMgr.baseToken()
    console.log('Base token is', baseToken)

    const poc = await hre.ethers.getContractAt("QuantumPortalPocUpgradeable", "0xa45baceeb0c6b072b17ef6483e4fb50a49dc5f4b") as any as QuantumPortalPocUpgradeable
    const nativeFeeRepoAddress = await poc.nativeFeeRepo()
    const nativeFeeRepoF = await hre.ethers.getContractAt("QuantumPortalNativeFeeRepoUpgradeable", nativeFeeRepoAddress)
    const nativeFeeRepo = nativeFeeRepoF.attach(nativeFeeRepoAddress) as QuantumPortalNativeFeeRepoUpgradeable
    const fc = await nativeFeeRepo.feeConvertor()
    console.log('Fee convertor is', fc)
    console.log('Fee target is', await poc.feeTarget())
    console.log('Fee tkoen is', await poc.feeToken())

    const feeConverterC = await hre.ethers.getContractAt("QuantumPortalFeeConverterDirectUpgradeable", fc) as any as QuantumPortalFeeConverterDirectUpgradeable
    const price = await feeConverterC.localChainGasTokenPrice()
    console.log('Price is', price)
}

main().then(() => process.exit(0))
