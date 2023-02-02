import { ethers } from "hardhat";
import { deployUsingDeployer, isAllZero, panick } from "../../../../test/common/Utils";
import { DEPLOYER_CONTRACT, DEPLPOY_SALT_1, DEPLPOY_SALT_2 } from "../../../consts";
import { MultiChainMasterBase } from '../../../../typechain/MultiChainMasterBase';
import { MultiChainClientBase } from '../../../../typechain/MultiChainClientBase';
import {createInterface} from "readline";

export interface TestContract {
    name: string;
    address: string;
    netId: number;
}

export interface DeployCliArgs {
    owner: string;
}

export function readLine(questionText: string) {
    const rl = createInterface({
        input: process.stdin,
        output: process.stdout
    });
    return new Promise<string>(resolve => rl.question(questionText, resolve))
        .finally(() => rl.close());
}

export class DeployTestHelper<T extends DeployCliArgs, C> {
    MASTER_CHAIN_ID = 97;
    CLIENT_CHAIN_ID = 80001;
    FERRUM_CHAIN_ID = 2600;
    qpPoc = '0x57f2FbAD5D6C8DaFfb268DF9D3D87d9E84Dad3Ef';
    args: T = {} as any;
    netId: number;
    private _deployed: C = {} as any;

    constructor(args: string[]) {
        args.push('owner');
        args.forEach(km => {
            const [k, m] = km.split(';');
            this.args[k] = process.env[k] || panick(m || `Provide ${k}`);
        });
    }

    deployed<T>(name: string): T {
        return this._deployed[name] as T;
    }

    async init(netId: number, cs: TestContract[]) {
        this.netId = netId;
        for(let c of cs.filter(c => !!c.address && !!c.name)) {
            this._deployed[c.name] = c.netId === netId ?
                await this.con(c.address, c.name) :
                { address: c.address } as any;
            if (!this._deployed[c.name]) {
                throw new Error(`Contract ${c.name} is not already deployed to address ${c.address}`);
            }
        }
    }

    async con(addr: string, name: string) {
        const f = await ethers.getContractFactory(name);
        const c = await f.attach(addr);
        if (await c.deployed()) {
            return c;
        }
        return undefined;
    }

    async tryDeploy(contract: string, initData: string) {
        console.log(`Deplying `, contract);
        if (!this._deployed[contract]) {
            console.log('DEP USING DD', contract, this.args.owner, initData, DEPLOYER_CONTRACT,
                DEPLPOY_SALT_2)
            const tok = await deployUsingDeployer(contract, this.args.owner, initData, DEPLOYER_CONTRACT,
                DEPLPOY_SALT_2);
            this._deployed[contract] = tok;
        } else {
            console.log(`Is already deplyed `, contract);
        }
    }

    async configMaster(_master: string, _client: string) {
        const master = this._deployed[_master] as MultiChainMasterBase;
        const client = this._deployed[_client] as MultiChainClientBase;
        if (this.CLIENT_CHAIN_ID && !!client) {
            const curRem = await master.remotes(this.CLIENT_CHAIN_ID);
            if (isAllZero(curRem)) {
                console.log('SETTING REMOTE ON MASTER')
                await master.setRemote(this.CLIENT_CHAIN_ID, client.address);
            }
        } else {
            console.log('NOT ABLE TO SET REMOTE YET. TRY AGAIN!')
        }
    }

    async configClient(_master: string, _client: string) {
        const master = this._deployed[_master] as MultiChainMasterBase;
        const client = this._deployed[_client] as MultiChainClientBase;
        const storedMaster = await client.masterContract();
        if (isAllZero(storedMaster)) {
            console.log('SETTING MASTER CHAIN ID ON CLIENT');
            await client.setMasterChainId(this.MASTER_CHAIN_ID);
            console.log('SETTING MASTER CONTRACT ON CLIENT');
            await client.setMasterContract(master.address);
        }
    }
}
