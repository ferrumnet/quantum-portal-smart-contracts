import { ethers } from "ethers";
import hre from "hardhat";

import artifact from "../artifacts/contracts/contracts-upgradeable/quantumPortal/poc/QuantumPortalLedgerMgrUpgradeable.sol/QuantumPortalLedgerMgrImplUpgradeable.json"

const rpcUrl = "https://testnet.dev.svcs.ferrumnetwork.io"
const provider = new ethers.JsonRpcProvider(rpcUrl);
const privateKey = process.env.QP_DEPLOYER_KEY!;
const wallet = new ethers.Wallet(privateKey, provider);


async function sendTransaction() {
  const ledgerMgrAddr = "0xba8be144Ca01B11aBd457Bc4d93cC8F67a94984e"
  const ledgerMgrProxy = new ethers.Contract(ledgerMgrAddr, artifact.abi, wallet);

  console.log(await ledgerMgrProxy.ledger());

}

sendTransaction();
