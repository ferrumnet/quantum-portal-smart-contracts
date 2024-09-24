import { ContractFactory, ethers } from "ethers";
import hre from "hardhat";

import artifact from "../artifacts/contracts/contracts-upgradeable/quantumPortal/poc/QuantumPortalGatewayUpgradeable.sol/QuantumPortalGatewayUpgradeable.json"
import portalArtifact from "../artifacts/contracts/contracts-upgradeable/quantumPortal/poc/QuantumPortalPocUpgradeable.sol/QuantumPortalPocImplUpgradeable.json"
import ledgerMgrArtifact from "../artifacts/contracts/contracts-upgradeable/quantumPortal/poc/QuantumPortalLedgerMgrUpgradeable.sol/QuantumPortalLedgerMgrImplUpgradeable.json"

const rpcUrl = "https://testnet.dev.svcs.ferrumnetwork.io"
const provider = new ethers.JsonRpcProvider(rpcUrl);
const privateKey = process.env.QP_DEPLOYER_KEY!;
const wallet = new ethers.Wallet(privateKey, provider);


async function sendTransaction() {
  const contract = new ethers.Contract("0xeC11d853f05e7174F43834AfCf31d52D6d01B552", artifact.abi, wallet);
  const ledgerMgr = new ethers.Contract("0xba8be144Ca01B11aBd457Bc4d93cC8F67a94984e", ledgerMgrArtifact.abi, wallet);
  const portal = new ethers.Contract("0x7719ad3651a953cFe05379d293D5D3D580D0E359", portalArtifact.abi, wallet);

  console.log(await contract.WFRM());
  console.log(await portal.feeToken());
  console.log(await ledgerMgr.ledger());
}

sendTransaction();
