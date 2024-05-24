import { ethers } from "hardhat";
import { Wei, ZeroAddress } from "../common/Utils";
import { TokenFactory } from '../../typechain-types/TokenFactory';
import { QpErc20Token } from '../../typechain-types/QpErc20Token';
import { Bitcoin } from '../../typechain-types/Bitcoin';
import { randomBytes } from "crypto";

describe("Deploy ", function () {
	it('Deploy a bunch of tokens', async function() {
        const facF = await ethers.getContractFactory('TokenFactory');
        const fac = await facF.deploy(ZeroAddress, ZeroAddress) as TokenFactory;

        // Make sure the implementations are there
        console.log(`runeImplementation: ${await fac.runeImplementation()}`);
        console.log(`runeBeacon: ${await fac.runeBeacon()}`);
        console.log(`btcImplementation: ${await fac.btcImplementation()}`);
        console.log(`btcBeacon: ${await fac.btcBeacon()}`);
        console.log(`btc: ${await fac.btc()}`);

        // Deploy a bunch of tokens
        await fac.deployRuneToken(
            10, 1, "TestRune", "TRN", 18, Wei.from('100000'), '0x'+randomBytes(32).toString('hex'));
        const justDeployed = await fac.getRuneTokenAddress(10, 1);
        console.log(`Just deployed: ${justDeployed}`);

        // Get contract code of qpTok
        const code = await ethers.provider.getCode(justDeployed);
        console.log(`Code: ${code}`);

        const qpTokF = await ethers.getContractFactory('QpErc20Token');
        const qpTok = await qpTokF.attach(justDeployed) as QpErc20Token;
        console.log(`Token name: ${await qpTok.name()}`);

        const btc = await qpTok.attach(await fac.btc()) as QpErc20Token;
        console.log(`BTC name: ${await btc.name()}`);
    });

    it('Can upgrade tokens', async function() {    
        const facF = await ethers.getContractFactory('TokenFactory');
        const fac = await facF.deploy(ZeroAddress, ZeroAddress) as TokenFactory;

        const btcF = await ethers.getContractFactory('Bitcoin');
        const btc = await btcF.attach(await fac.btc()) as Bitcoin;
        console.log(`BTC ${await fac.btcImplementation()} name: ${await btc.name()} (${await btc.symbol()})`);

        // Deploy dummyUpgradedToken
        const dummyF = await ethers.getContractFactory('DummyUpgradedToken');
        const dummy = await dummyF.deploy() as QpErc20Token;

        // Now upgrade the token to a new implementation
        await fac.upgradeImplementations(await fac.runeImplementation(), dummy.address, ZeroAddress);
        console.log(`BTC ${await fac.btcImplementation()} name: ${await btc.name()} (${await btc.symbol()})`);
    });

    it('Upgrade many at once', async function() {
        const facF = await ethers.getContractFactory('TokenFactory');
        const fac = await facF.deploy(ZeroAddress, ZeroAddress) as TokenFactory;
        const tokIds = ['101', '102', '103', '104', '105'];

        console.log('Deploying tokens');
        for(const tokId of tokIds) {
            await fac.deployRuneToken(
                parseInt(tokId), 1, `RUNE ${tokId}`, `RNE-${tokId}`, 18, Wei.from('100000'), '0x'+randomBytes(32).toString('hex'));
        }

        console.log('Before upgrade');
        for(const tokId of tokIds) {
            const tok = await fac.getRuneTokenAddress(parseInt(tokId), 1);
            const rune = await ethers.getContractAt('QpErc20Token', tok) as QpErc20Token;
            console.log(`RUNE name: ${await rune.name()} (${await rune.symbol()})`);
        }

        // Deploy dummyUpgradedToken
        const dummyF = await ethers.getContractFactory('DummyUpgradedToken');
        const dummy = await dummyF.deploy() as QpErc20Token;
        console.log('Upgrading tokens');
        await fac.upgradeImplementations(dummy.address, await fac.btcImplementation(), ZeroAddress);

        console.log('Check upgraded tokens');
        for(const tokId of tokIds) {
            const tok = await fac.getRuneTokenAddress(parseInt(tokId), 1);
            const rune = await ethers.getContractAt('QpErc20Token', tok) as QpErc20Token;
            console.log(`RUNE name: ${await rune.name()} (${await rune.symbol()})`);
        }
    });
});