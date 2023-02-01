import { Wei } from "../../common/Utils";
import { ethers } from "hardhat";
import { expect } from "chai";
import { advanceTimeAndBlock } from "../../common/TimeTravel";
import { MultiChainToken } from '../../../typechain/MultiChainToken';
import { deployAll, QuantumPortalUtils } from "./QuantumPortalUtils";

describe("Mint and move", function () {
	it('Mint on master and move to other chains!', async function() {
        const ctx = await deployAll();
        console.log('Mint the x-chain token', ctx.sks);
	    const tokFac = await ethers.getContractFactory("MultiChainToken");
        const tok1 = await tokFac.deploy(ctx.chain1.chainId) as MultiChainToken;
        await tok1.init(ctx.chain1.chainId, ctx.chain1.poc.address, ctx.owner);
        const tok2 = await tokFac.deploy(ctx.chain2.chainId) as MultiChainToken;
        await tok2.init(ctx.chain1.chainId, ctx.chain2.poc.address, ctx.owner);
        await tok2.setRemote(ctx.chain1.chainId, tok1.address);
        await tok1.setRemote(ctx.chain2.chainId, tok2.address);
        console.log('Pair of tok1 is', tok2.address, 'chain 1 ctx', ctx.chain1.poc.address);
        console.log('Pair of tok2 is', tok1.address, 'chain 2 ctx', ctx.chain2.poc.address);
        console.log('Chain ids are ', await tok1.CHAIN_ID(), await tok2.CHAIN_ID());

        let sup1 = Wei.to((await tok1.totalSupply()).toString());
        let sup2 = Wei.to((await tok2.totalSupply()).toString());
        console.log(`PRE - Supplies: 1) ${sup1} - 2) ${sup2}`);

        await tok1.mintAndBurn(ctx.chain2.chainId, ctx.chain1.chainId, Wei.from('10'), Wei.from('1'), Wei.from('1'));

        console.log('Moving time forward');
        await advanceTimeAndBlock(120); // Two minutes
        const mined = await QuantumPortalUtils.mine(ctx.chain1.chainId, ctx.chain2.chainId,
            ctx.chain1.ledgerMgr, ctx.chain2.ledgerMgr, ctx.sks[0]);
        expect(mined).to.be.true;
        await QuantumPortalUtils.finalize(ctx.chain1.chainId, ctx.chain2.ledgerMgr);

        console.log('Sweet! Now we should be all good'); 
        sup1 = Wei.to((await tok1.totalSupply()).toString());
        sup2 = Wei.to((await tok2.totalSupply()).toString());
        console.log(`POST - Supplies: 1) ${sup1} - 2) ${sup2}`);
    });
});