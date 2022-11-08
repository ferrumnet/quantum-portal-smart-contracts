import { abi, deployUsingDeployer, Wei } from "../../common/Utils";
import { ethers } from "hardhat";
import { expect } from "chai";
import { advanceTimeAndBlock } from "../../common/TimeTravel";
import { MitlChainToken2Client } from '../../../typechain/MitlChainToken2Client';
import { MitlChainToken2Master } from '../../../typechain/MitlChainToken2Master';
import { deployAll, QuantumPortalUtils } from "./QuantumPortalUtils";
import { DEPLOYER_CONTRACT, DEPLPOY_SALT_1 } from "../../../scripts/consts";

describe("Mint and move", function () {
	it('Mint on master and move to other chains!', async function() {
        const ctx = await deployAll();
        console.log('Mint the x-chain token');
        const masterInitData = abi.encode(['address', 'uint256'], 
            [ctx.chain1.poc.address, ctx.chain1.chainId]);
        const tokMaster = await deployUsingDeployer(
            'MitlChainToken2Master', ctx.owner, masterInitData, ctx.deployer.address, DEPLPOY_SALT_1
            ) as MitlChainToken2Master;
        await tokMaster.initialMint(); // Mint the initial amount;
        let totalSupplyMaster = (await tokMaster.totalSupply()).toString();
        console.log('Total supply Master: ', Wei.to(totalSupplyMaster));

        const clientInitData = abi.encode(['address', 'uint256'], 
            [ctx.chain2.poc.address, ctx.chain2.chainId]);
        const tokClient = await deployUsingDeployer(
            'MitlChainToken2Client', ctx.owner, clientInitData, ctx.deployer.address, DEPLPOY_SALT_1
            ) as MitlChainToken2Client;
        await tokClient.setMasterContract(tokMaster.address);
        let totalSupplyClient = (await tokClient.totalSupply()).toString();
        console.log('Total supply Client: ', Wei.to(totalSupplyClient));

        await tokMaster.setRemote(ctx.chain2.chainId, tokClient.address);

        let sup1 = Wei.to((await tokMaster.totalSupply()).toString());
        let sup2 = Wei.to((await tokClient.totalSupply()).toString());
        console.log(`PRE - Supplies: 1) ${sup1} - 2) ${sup2}`);

        await tokMaster.mintAndBurn(ctx.chain2.chainId, ctx.chain1.chainId, Wei.from('10'), Wei.from('1'), Wei.from('1'));

        console.log('Moving time forward');
        await advanceTimeAndBlock(120); // Two minutes
        const mined = await QuantumPortalUtils.mine(ctx.chain1.chainId, ctx.chain2.chainId, ctx.chain1.ledgerMgr, ctx.chain2.ledgerMgr);
        expect(mined).to.be.true;
        await QuantumPortalUtils.finalize(ctx.chain1.chainId, ctx.chain2.ledgerMgr);

        console.log('Remember master token is deployed at ', tokMaster.address);
        console.log('Sweet! Now we should be all good'); 
        sup1 = Wei.to((await tokMaster.totalSupply()).toString());
        sup2 = Wei.to((await tokClient.totalSupply()).toString());
        console.log(`POST - Supplies: 1) ${sup1} - 2) ${sup2}`);
    });
});