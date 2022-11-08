import { abi, deployUsingDeployer, panick } from "../../../../test/common/Utils";
import { MultiChainToken } from "../../../../typechain/MultiChainToken";
import { DEPLOYER_CONTRACT, DEPLPOY_SALT_1 } from "../../../consts";

const FERRUM_CHAIN_ID = 2600;
const deployedAddr = '0x83A4bE8304067c2211EaB5aA0cc17D0083b4Efe5';
const qpPoc = '0x010aC4c06D5aD5Ad32bF29665b18BcA555553151';

async function main() {
    const owner: string = process.env.OWNER || panick('provide OWNER');
    const initData = abi.encode(['string', 'string', 'uint256'], ['Muti chain test token', 'MCTT', 0]);
    const tok = await deployUsingDeployer('MultiChainToken', owner, initData, DEPLOYER_CONTRACT,
        DEPLPOY_SALT_1) as MultiChainToken;
    // Set the QP POC
    await tok.init(FERRUM_CHAIN_ID, qpPoc, owner);
}
  
main()
	.then(() => process.exit(0))
	.catch(error => {
	  console.error(error);
	  process.exit(1);
});
