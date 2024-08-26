import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ignition-ethers";
import "hardhat-contract-sizer"
import "@nomicfoundation/hardhat-verify";
import { Secrets } from "foundry-contracts/dist/test/common/Secrets";

import { TEST_MNEMONICS } from "./test/common/TestAccounts";
import { ethers } from "ethers";
require("dotenv").config({path: __dirname + '/localConfig/.env'});

const getEnv = (env: string) => {
  const value = process.env[env];
  if (typeof value === "undefined") {
    console.warn(`${env} has not been set.`);
    // throw new Error(`${env} has not been set.`);
  }
  return value;
};


let accounts: any = undefined;
if (process.env.PAIVATE_KEY_SECRET_ARN) {
  console.log('Using AWS Secrets Manager for private keys');
  Secrets.fromAws(process.env.PAIVATE_KEY_SECRET_ARN).then((secret: any) => {
    const hre = require("hardhat");
    // Use the default mnemonics
    // accounts = { mnemonic: secret.DEV_MNEMONICS };
    // Or use a single account. Check available keys from the secret manager
    const accounts = [secret.PRIVATEKEY_TEST_VALIDATOR];

    const nets = Object.keys(hre.config.networks);
    nets.forEach((network) => {
      hre.config.networks[network].accounts = accounts;
    });
    logLocalAccount(accounts);
  }).catch((e: any) => {
    console.error('Failed to get secret from PAIVATE_KEY_SECRET_ARN environment', e);
  });
} else {
  accounts = process.env.TEST_ACCOUNT_PRIVATE_KEY ? [process.env.TEST_ACCOUNT_PRIVATE_KEY] : { mnemonic: TEST_MNEMONICS };
  logLocalAccount(accounts);
}

function logLocalAccount(accounts: any) {
  if (accounts.mnemonic) {
      let mnemonicWallet = ethers.HDNodeWallet.fromPhrase(accounts.mnemonic);
      console.log('Test account used from MNEMONIC', mnemonicWallet.privateKey, mnemonicWallet.address);
  } else {
      let wallet = new ethers.Wallet(accounts[0]);
      console.log('Single test account used:', wallet.address);
  }
}

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  solidity: {
    compilers: [
      {
        version: "0.8.24",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      blockGasLimit: 3000000000,
      allowUnlimitedContractSize: true,
      accounts,
    },
    local: {
      // chainId: 97,
      url: 'http://127.0.0.1:8545',
      accounts,
      // gas: 1000000,
      // gasPrice: 20000000000,
    },
    btfd_ghostnet: {
      chainId: 42,
      url: "http://ghostnet.dev.svcs.ferrumnetwork.io:9944",
      allowUnlimitedContractSize: true,
      accounts,
      //gas: 10000000, // this override is required for Substrate based evm chains
    },
    mainnet: {
      chainId: 1,
      url: getEnv('ETH_LIVE_NETWORK'),// `https://eth-mainnet.alchemyapi.io/v2/${getEnv("ALCHEMY_API_KEY") || "123123123"}`,
      gasPrice: 18000000000,
      accounts,
    },
    // bsctestnet: {
    //   chainId: 97,
    //   url: getEnv("BSC_TESTNET_LIVE_NETWORK"),
    //   accounts,
    //   gas: 1000000,
    //   // gasPrice: 20000000000,
    // },
    bsc: {
      chainId: 56,
      url: "https://bsc-dataseed2.defibit.io",
      accounts,
      // accounts: [process.env.QP_DEPLOYER_KEY!]
    },
    moonbeam: {
      chainId: 1287,
      url: "https://rpc.api.moonbase.moonbeam.network",
      allowUnlimitedContractSize: true,
      gas: 10000000, // this override is required for Substrate based evm chains
      accounts,
    },
    matic: {
      chainId: 137,
      url: "https://rpc-mainnet.maticvigil.com/",
      gasPrice: 16000000000,
      accounts,
    },
    mumbai: {
      chainId: 80001,
      url: "https://rpc-mumbai.maticvigil.com/",
      accounts,
      // accounts: [process.env.QP_DEPLOYER_KEY!]
      // gasPrice: 16000000000,
      // gas: 10000000,
    },
    avax: {
      chainId: 43114,
      url: "https://api.avax.network/ext/bc/C/rpc",
      accounts,
    },
    avaxtestnet: {
      chainId: 43113,
      url: "https://api.avax-test.network/ext/bc/C/rpc",
      accounts,
    },
    ferrum_testnet_poc: {
      chainId: 26000,
      url: "http://testnet.dev.svcs.ferrumnetwork.io:9933",
      accounts,
    },
    shibuya_testnet: {
      chainId: 4369,
      url: "http://127.0.0.1:9933/",
      allowUnlimitedContractSize: true,
      // gas: 10000000, // this override is required for Substrate based evm chains
      accounts,
    },
    arbitrumOne: {
      url: 'https://nd-829-997-700.p2pify.com/790712c620e64556719c7c9f19ef56e3',
      // accounts: [process.env.QP_DEPLOYER_KEY!]
      accounts,
    },
    base: {
      url: 'https://base-mainnet.core.chainstack.com/e7aa01c976c532ebf8e2480a27f18278',
      // accounts: [process.env.QP_DEPLOYER_KEY!]
      accounts,
    },
    ferrum_testnet: {
      chainId: 26100,
      url: "https://testnet.dev.svcs.ferrumnetwork.io",
      // accounts: [process.env.QP_DEPLOYER_KEY!],
      allowUnlimitedContractSize: true,
      gas: 10000000, // this override is required for Substrate based evm chains
      accounts,
    },
  },
  etherscan: {
    // Your API key for Etherscan
    apiKey: {
      // bscTestnet: getEnv("BSCSCAN_API_KEY"),
      // polygonMumbai: getEnv("POLYGONSCAN_API_KEY"),
      // btfd_ghostnet: getEnv("POLYGONSCAN_API_KEY"),
      arbitrumOne: process.env.ARBISCAN_API_KEY!,
      base: process.env.BASESCAN_API_KEY!,
      bsc: process.env.BSCSCAN_API_KEY!,
  },
  customChains: [
    {
      network: "btfd_ghostnet",
      chainId: 42,
      urls: {
        apiURL: "https://ghostnet.dev.svcs.ferrumnetwork.io/api/",
        browserURL: "https://ghostnet.dev.svcs.ferrumnetwork.io/"
      }
    }
  ]
  },
  sourcify: {
    // Disabled by default
    // Doesn't need an API key
    enabled: true,
    apiUrl: "https://sourcify.dev/server",
    browserUrl: "https://repo.sourcify.dev",
  },
  ignition: {
    strategyConfig: {
      create2: {
        // To learn more about salts, see the CreateX documentation
        salt: "0x0000000000000000000000000000000000000000000000000000000000000005"
        // salt: "0x46657272756D4E6574776F726B2D746573746E65743A30312E3030312E303033",
      },
    },
  },
};

export default config;
