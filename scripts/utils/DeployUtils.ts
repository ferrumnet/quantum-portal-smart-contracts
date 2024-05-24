import * as fs from 'fs';
import { parse } from 'yaml'
import { panick } from '../../test/common/Utils';

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
    QuantumPortalMinStake?: string;
    UniswapOracle?: string;
    QuantumPortalBtcWallet?: string;
    FRM: { [NetworkId in number]: string; }
    WETH: { [NetworkId in number]: string; }
    WFRM: string;
    UniV2Factory: { [NetworkId in number]: string; }
    DeployerKeys: {
        DeployerContract?: string;
        Qp?: string;
        Owner?: string;
    }
    DirectFee: {
        feePerByte: string
    }
}

export function loadQpDeployConfig(path: string) {
    const data = fs.readFileSync(path).toString();
    const rv = parse(data) as QpDeployConfig;
    if (!rv.WFRM || !rv.FRM || !rv.DeployerKeys || !rv.WETH || !rv.UniV2Factory) {
        throw new Error(`Invalid config. Required: WFrm, Frm, WETH, UniV2Factory, and DeployerKeys`);
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