import { HardhatUserConfig } from "hardhat/types";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";
import '@typechain/hardhat';
import "@nomiclabs/hardhat-etherscan";
import '@openzeppelin/hardhat-upgrades';
require('dotenv').config({ path: __dirname + '/.env' });


const getEnv = (env: string) => {
	const value = process.env[env];
	if (typeof value === 'undefined') {
	  console.warn(`${env} has not been set.`);
	  throw new Error(`${env} has not been set.`);
	}
	return value;
};

const TEST_MNEMONICS = 'body sound phone helmet train more almost piano motor define basic retire play detect force ten bamboo swift among cinnamon humor earn coyote adjust';

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  solidity: {
    compilers: [{ version: "0.8.2", settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    } }],
  },
  networks: {
		hardhat: {
      accounts: {
        mnemonic: TEST_MNEMONICS,
      },
      blockGasLimit: 50000000
		},
    local: {
	    chainId: 31337,
      url: `http://127.0.0.1:8545/`,
      accounts: {
        mnemonic: TEST_MNEMONICS,
      },
	    // gasPrice: 18000000000,
    },
    mainnet: {
	  chainId: 1,
      url: `https://eth-mainnet.alchemyapi.io/v2/${getEnv('ALCHEMY_API_KEY') || '123123123'}`,
      accounts: [getEnv('TEST_ACCOUNT_PRIVATE_KEY')],
	  gasPrice: 18000000000,
    },
	bsctestnet: {
	  chainId: 97,
      url: getEnv('BSC_TESTNET_LIVE_NETWORK'),
      accounts: [getEnv('TEST_ACCOUNT_PRIVATE_KEY')],
	//   gasPrice: 20000000000,
	},
	bsc: {
	  chainId: 56,
      url: getEnv('BSC_LIVE_NETWORK'),
      accounts: [getEnv('TEST_ACCOUNT_PRIVATE_KEY')],
	},
	matic: {
	  chainId: 137,
      url: 'https://rpc-mainnet.maticvigil.com/',
      accounts: [getEnv('TEST_ACCOUNT_PRIVATE_KEY')],
			gasPrice: 16000000000,
	},
	mumbai: {
	  chainId: 80001,
      url: 'https://rpc-mumbai.maticvigil.com/',
      accounts: [getEnv('TEST_ACCOUNT_PRIVATE_KEY')],
			// gasPrice: 16000000000,
			// gas: 10000000,
	},
    avax: {
        chainId: 43114,
        url: 'https://api.avax.network/ext/bc/C/rpc',
        accounts: [getEnv('TEST_ACCOUNT_PRIVATE_KEY')],
    },
    avaxtestnet: {
        chainId: 43113,
        url: 'https://api.avax-test.network/ext/bc/C/rpc',
        accounts: [getEnv('TEST_ACCOUNT_PRIVATE_KEY')],
    },
    ferrum_testnet_poc: {
          chainId: 26000,
          url: 'http://localhost:9933/',
      	  accounts: [getEnv('TEST_ACCOUNT_PRIVATE_KEY')],
    }
  },
  etherscan: {
    // Your API key for Etherscan
     apiKey: {
      bscTestnet: getEnv('BSCSCAN_API_KEY'),
      polygonMumbai : getEnv('POLYGONSCAN_API_KEY'),
     }
  }
};
export default config;
