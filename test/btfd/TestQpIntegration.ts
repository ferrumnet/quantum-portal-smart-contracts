
import { ethers } from "hardhat";
import { Wei, ZeroAddress, abi, expiryInFuture, printSeparator } from "../common/Utils";
import { TokenFactory } from '../../typechain-types/TokenFactory';
import { QpErc20Token } from '../../typechain-types/QpErc20Token';
import { QpMultiSender } from '../../typechain-types/QpMultiSender';
import { QuantumPortalUtils, deployAll } from "../quantumPortal/poc/QuantumPortalUtils";
import { randomSalt } from "../common/Eip712Utils";
import { expect } from "chai";

function _it(a,b) { return () => {} }

function sats(num: string) {
    return ethers.utils.parseUnits(num, 'gwei');
}

describe("Deploy QP - Deploy BTDD, Test a remote call ", function () {
	it('Test remote call', async function() {
        console.log('Deploying qp');
        const ctx = await deployAll();
        const QpWallet = ctx.acc5;
        printSeparator();

        console.log('GAS LOCAL TOKEN PRICE', await ctx.chain1.feeConverter.localChainGasTokenPriceX128());
    
        console.log('Deploying BTFD')
        const facF = await ethers.getContractFactory('TokenFactory');
        const fac = await facF.deploy(ctx.chain1.poc.address, ctx.chain1.feeConverter.address, QpWallet, QpWallet) as TokenFactory;
        console.log('Btc address: ', await fac.btc());
        console.log('Send some fee to the feeStroe');
        await ctx.chain1.token.transfer(await fac.feeStore(), Wei.from('100'));
        console.log(`We have fee in the fee store: ${await ctx.chain1.token.balanceOf(await fac.feeStore())}`);
        printSeparator();

        console.log('Now do a BTC trasnfer');
        const qpTokF = await ethers.getContractFactory('QpErc20Token');
        const btc = await qpTokF.attach(await fac.btc()) as QpErc20Token;

        const timestamp = expiryInFuture(); // Just some timestamp for the btc tx
        console.log('Minting some BTC');
        await btc.multiTransfer([], [], [ctx.acc1], [sats('10')], 99,
            randomSalt(), timestamp, '0x');
        console.log('Balance :', await btc.balanceOf(ctx.acc1), ' This is supposed to be real BTC');

        const methodCall = btc.interface.encodeFunctionData('remoteTransfer');
        console.log('METHOD CALL IUS:', methodCall);
        // Send 1 BTC to acc2, with 3 fee.
        const remoteCall = abi.encode(['uint64', 'address', 'address', 'bytes', 'uint'],
            [ctx.chain1.chainId, ctx.acc2, btc.address, methodCall, sats('1')]);

        const btcBalanceBeforeFeeStore = Wei.to((await btc.balanceOf(await fac.feeStore())).toString());
        const frmBalanceBeforeFeeStore = Wei.to((await ctx.chain1.token.balanceOf(await fac.feeStore())).toString());
        console.log('QPBTC balance for fee store :', btcBalanceBeforeFeeStore);
        console.log('FRM balance for fee store :', frmBalanceBeforeFeeStore);

        await btc.multiTransfer([ctx.acc1], [sats('10')], [ctx.acc1, QpWallet], [sats('7'), sats('3')], 100,
            randomSalt() /*txId*/, timestamp, remoteCall);

        const btcBalanceAfterFeeStore = Wei.to((await btc.balanceOf(await fac.feeStore())).toString());
        const frmBalanceAfterFeeStore = Wei.to((await ctx.chain1.token.balanceOf(await fac.feeStore())).toString());
        console.log('QPBTC balance for fee store after :', btcBalanceAfterFeeStore);
        console.log('FRM balance for fee store after :', frmBalanceAfterFeeStore);
        expect(btcBalanceBeforeFeeStore).to.equal('0.0');
        expect(btcBalanceAfterFeeStore).to.equal('1.0');
        expect(frmBalanceBeforeFeeStore).to.equal('100.0');
        expect(frmBalanceAfterFeeStore).to.equal('99.0');

        const qpBalanceBefore = Wei.to((await btc.balanceOf(QpWallet)).toString());
        const qpBalanceBeforeBtc = Wei.to((await btc.balanceOf(QpWallet)).toString());
        const balanceBefore = Wei.to((await btc.balanceOf(ctx.acc2)).toString());
        const balanceBeforeBtc = Wei.to((await btc.balanceOf(ctx.acc2)).toString());
        console.log('QP Balance before :', qpBalanceBefore);
        console.log('QP BTC Balance before :', qpBalanceBeforeBtc);
        console.log('Balance before :', balanceBefore);
        console.log('BTC Balance before :', balanceBeforeBtc);
        console.log('Now mining');
        printSeparator();
        await QuantumPortalUtils.mineAndFinilizeOneToOne(ctx, 1);
        printSeparator();
        const qpBalanceAfter = Wei.to((await btc.balanceOf(QpWallet)).toString());
        const qpBalanceAfterBtc = Wei.to((await btc.balanceOf(QpWallet)).toString());
        const balanceAfter = Wei.to((await btc.balanceOf(ctx.acc2)).toString());
        const balanceAfterBtc = Wei.to((await btc.balanceOfBtc(ctx.acc2)).toString());
        console.log('QP Balance after :', qpBalanceAfter);
        console.log('QP BTC Balance after :', qpBalanceAfterBtc);
        console.log('Balance after :', balanceAfter);
        console.log('BTC Balance after :', balanceAfterBtc);

        // Asserting the following:
        // Befoer QP mining, QP Wallet has 1 real BTC. 0 QP BTC
        // User has 0 real BTC, 0 QP BTC
        // After transfer we mint 1 QP BTC to the user, but there is no change
        // in the real BTC balance.
        expect(qpBalanceBefore).to.equal('3.0');
        expect(qpBalanceBeforeBtc).to.equal('3.0');
        expect(balanceBefore).to.equal('0.0');
        expect(balanceBeforeBtc).to.equal('0.0');
        expect(qpBalanceAfter).to.equal('3.0');
        expect(qpBalanceAfterBtc).to.equal('3.0');
        expect(balanceAfter).to.equal('2.0');
        expect(balanceAfterBtc).to.equal('0.0');
    });

	_it('Test example for MultiSend', async function() {
        console.log('Deploying qp');
        const ctx = await deployAll();
        const QpWallet = ctx.acc5;
        printSeparator();

        console.log('GAS LOCAL TOKEN PRICE', await ctx.chain1.feeConverter.localChainGasTokenPriceX128());
    
        console.log('Deploying BTFD')
        const facF = await ethers.getContractFactory('TokenFactory');
        const fac = await facF.deploy(ctx.chain1.poc.address, QpWallet) as TokenFactory;
        console.log('Btc address: ', await fac.btc());

        const msF = await ethers.getContractFactory('QpMultiSender');
        const ms = await msF.deploy(ctx.chain1.poc.address) as QpMultiSender;
        console.log(`Multisender deployed at`, ms.address);
        printSeparator();

        console.log('Now do a BTC trasnfer');
        const qpTokF = await ethers.getContractFactory('QpErc20Token');
        const btc = await qpTokF.attach(await fac.btc()) as QpErc20Token;

        const timestamp = expiryInFuture(); // Just some timestamp for the btc tx
        console.log('Minting some BTC');
        await btc.multiTransfer([], [], [ctx.acc1], [Wei.from('10')], 99,
            randomSalt(), timestamp, '0x');
        console.log('Balance :', await btc.balanceOf(ctx.acc1));

        console.log('Send some fee to token');
        await ctx.chain1.token.transfer(btc.address, Wei.from('10'));
        console.log(`We have fee in the contract: ${await ctx.chain1.token.balanceOf(btc.address)}`)

        const targets: string[] = [ctx.acc2, ctx.acc3, ctx.acc5];
        const methodCall = ms.interface.encodeFunctionData('qpMultiSend', [targets]);
        console.log('METHOD CALL IUS:', methodCall);
        // Send 1 BTC to acc2, with 3 fee.
        const remoteCall = abi.encode(['uint64', 'address', 'address', 'bytes', 'uint'],
            [ctx.chain1.chainId, ZeroAddress, ms.address, methodCall, Wei.from('3')]);
        await btc.multiTransfer([ctx.acc1], [Wei.from('10')], [ctx.acc1, QpWallet], [Wei.from('9'), Wei.from('1')], 100,
            randomSalt() /*txId*/, timestamp, remoteCall);

        const qpBalanceBeforeP = targets.map(t => btc.balanceOf(t));
        const qpBalanceBefore = await Promise.all(qpBalanceBeforeP);
        console.log('QP Balance before :', qpBalanceBefore.map(b => Wei.to(b.toString())));
        console.log('Now mining');
        printSeparator();
        await QuantumPortalUtils.mineAndFinilizeOneToOne(ctx, 1);
        printSeparator();
        const qpBalanceAfterP = targets.map(t => btc.balanceOf(t));
        const qpBalanceAfter = await Promise.all(qpBalanceAfterP);
        console.log('QP Balance after :', qpBalanceAfter.map(b => Wei.to(b.toString())));
    });
});