import * as fs from 'fs';
import { parse } from 'yaml'
import { panick } from '../../test/common/Utils';

export interface QpDeployConfig {
    Owner: string;
    DeployerContract: string;
    DeployerSalt; string;
    QuantumPortalGateway?: string;
    QuantumPortalPoc?: string;
    QuantumPortalLedgerMgr?: string;
    QuantumPortalAuthorityMgr?: string;
    QuantumPortalMinerMgr?: string;
    QuantumPortalStake?: string;
    FRM: { [NetworkId in number]: string; }
    WFRM: string;
    DeployerKeys: {
        DeployerContract?: string;
        Qp?: string;
        Owner?: string;
    }
}

export function loadQpDeployConfig(path: string) {
    const data = fs.readFileSync(path).toString();
    const rv = parse(data) as QpDeployConfig;
    if (!rv.WFRM || !rv.FRM || !rv.DeployerKeys) {
        throw new Error(`Invalid config. Required: WFrm, Frm, and DeployerKeys`);
    }
    updateDeployerKey(rv, 'DeployerContract');
    updateDeployerKey(rv, 'Qp');
    updateDeployerKey(rv, 'Owner');
    if (!rv.DeployerKeys.Owner && !rv.Owner) {
        throw new Error(`Invalid config. Owner, or its DeployerKey is required`);
    }
    return rv;
}

function updateDeployerKey(conf: QpDeployConfig, key: string) {
    const val = conf.DeployerKeys[key];
    if (!!val) {
        if (val.startsWith('$')) {
            conf.DeployerKeys[key] = process.env[val.replace('$', '')] || panick(`Environment variable required for ${val}`)
        }
    }
}