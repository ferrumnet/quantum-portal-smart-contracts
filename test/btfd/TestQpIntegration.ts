
import { ethers } from "hardhat";
import { Wei, ZeroAddress, abi, expiryInFuture, printSeparator } from "../common/Utils";
import { TokenFactory } from '../../typechain-types/TokenFactory';
import { QpErc20Token } from '../../typechain-types/QpErc20Token';
import { QuantumPortalUtils, deployAll } from "../quantumPortal/poc/QuantumPortalUtils";
import { randomSalt } from "../common/Eip712Utils";
import { expect } from "chai";

describe("Deploy QP - Deploy BTDD, Test a remote call ", function () {
	it('Test remote call', async function() {
        console.log('Deploying qp');
        const ctx = await deployAll();
        const QpWallet = ctx.acc5;
        printSeparator();
    
        console.log('Deploying BTFD')
        const facF = await ethers.getContractFactory('TokenFactory');
        const fac = await facF.deploy(ctx.chain1.poc.address, QpWallet) as TokenFactory;
        console.log('Btc address: ', await fac.btc());
        printSeparator();

        console.log('Now do a BTC trasnfer');
        const qpTokF = await ethers.getContractFactory('QpErc20Token');
        const btc = await qpTokF.attach(await fac.btc()) as QpErc20Token;

        const timestamp = expiryInFuture();
        console.log('Minting some BTC');
        await btc.multiTransfer([], [], [ctx.acc1], [Wei.from('10')], 99,
            randomSalt(), timestamp, '0x');
        console.log('Balance :', await btc.balanceOf(ctx.acc1));

        console.log('Send some fee to token');
        await ctx.chain1.token.transfer(btc.address, Wei.from('10'));
        console.log(`We have fee in the contract: ${await ctx.chain1.token.balanceOf(btc.address)}`)

        const methodCall = btc.interface.encodeFunctionData('remoteTransfer');
        console.log('METHOD CALL IUS:', methodCall);
        console.log('aND', await btc.whatIs());
        const remoteCall = abi.encode(['uint64', 'address', 'address', 'bytes', 'uint'],
            [ctx.chain1.chainId, ctx.acc2, btc.address, methodCall, Wei.from('1')]);
        await btc.multiTransfer([ctx.acc1], [Wei.from('10')], [ctx.acc1, QpWallet], [Wei.from('9'), Wei.from('1')], 100,
            randomSalt(), timestamp, remoteCall);

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
        expect(qpBalanceBefore).to.equal('1.0');
        expect(qpBalanceBeforeBtc).to.equal('1.0');
        expect(balanceBefore).to.equal('0.0');
        expect(balanceBeforeBtc).to.equal('0.0');
        expect(qpBalanceAfter).to.equal('1.0');
        expect(qpBalanceAfterBtc).to.equal('1.0');
        expect(balanceAfter).to.equal('1.0');
        expect(balanceAfterBtc).to.equal('0.0');
    });
});