import * as fs from 'fs';
import * as yaml from 'js-yaml';
import { parse } from 'yaml'
import { panick } from '../../test/common/Utils';
import { Secrets } from 'foundry-contracts/dist/test/common/Secrets';
import deasync from 'deasync';

export type ConfigKeyItem = { type: 'aws' | 'string', value?: string; field?: string; env?: string} | string;

export interface QpDeployConfig {
    Owner: string;
    DeployerContract: string;
    DeployerSalt; string;
    QuantumPortalGateway?: string;
    QuantumPortalState?: string;
    QuantumPortalPoc?: string;
    QuantumPortalLedgerMgr?: string;
    QuantumPortalAuthorityMgr?: string;
    QuantumPortalFeeConvertor?: string;
    QuantumPortalFeeConvertorDirect?: string;
    QuantumPortalMinerMgr?: string;
    QuantumPortalStake?: string;
    QuantumPortalNativeFeeRepo?: string;
    QuantumPortalMinStake?: string;
    UniswapOracle?: string;
    QuantumPortalBtcWallet?: string;
    BTFDTokenDeployer?: string;
    FRM: { [NetworkId in number]: string; }
    WETH: { [NetworkId in number]: string; }
    WFRM: string;
    UniV2Factory: { [NetworkId in number]: string; }
    DeployerKeys: {
        DeployerContract?: ConfigKeyItem;
        Qp?: ConfigKeyItem;
        Owner?: ConfigKeyItem;
    }
    DirectFee: {
        feePerByte: string
    }
}

export async function loadQpDeployConfig(path: string) {
    const data = fs.readFileSync(path).toString();
    const rv = parse(data) as QpDeployConfig;
    if (!rv.WFRM || !rv.FRM || !rv.DeployerKeys || !rv.WETH || !rv.UniV2Factory) {
        throw new Error(`Invalid config. Required: WFrm, Frm, WETH, UniV2Factory, and DeployerKeys`);
    }
    await updateDeployerKey(rv, 'DeployerContract');
    await updateDeployerKey(rv, 'Qp');
    await updateDeployerKey(rv, 'Owner');
    if (!rv.DeployerKeys.Owner && !rv.Owner) {
        throw new Error(`Invalid config. Owner, or its DeployerKey is required`);
    }
    return rv;
}

async function updateDeployerKey(conf: QpDeployConfig, key: string) {
    const val = conf.DeployerKeys[key] as ConfigKeyItem;
    if (!val) { return null; }
    if (typeof(val) === 'string') {
        if (val.startsWith('$')) {
            conf.DeployerKeys[key] = process.env[val.replace('$', '')] || panick(`Environment variable required for ${val}`)
        }
    } else {
        if (val.type === 'aws') {
            const arn = !!val.env ? process.env[val.env] : val.value;
            const secret = await Secrets.fromAws(arn);
            conf.DeployerKeys[key] = !!val.field ? secret[val.field] : secret;
        } else { // its 'string'
            conf.DeployerKeys[key] = !!val.env ? process.env[val.env] : val.value;
        }
    }
}

export const loadConfig = (filePath: string) => {
    try {
      const fileContents = fs.readFileSync(filePath, 'utf8');
      const data = yaml.load(fileContents);
      return data;
    } catch (error) {
      console.error(`Error loading YAML file: ${error}`);
      return null;
    }
  };

export function loadQpDeployConfigSync(path: string) {
    let configFile = { val: {} as any, loaded: false };
    console.log('Loading config file, sync');
    let done = false;
    loadQpDeployConfig(path).then((conf) => {
        console.log('Config loaded sync...')
        configFile.val = conf;
        configFile.loaded = true;
        done = true;
    }).catch((e) => {;
        console.error('Failed to get secret from PAIVATE_KEY_SECRET_ARN environment', e);
        done = true;
    });

    while (!done) { deasync.sleep(100); } // Sync the secrets call
    if (configFile.loaded) {
        return configFile.val;
    }
    throw new Error("Couldn''t load config file");
}

