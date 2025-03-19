import hre from "hardhat"
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import { loadConfig, QpDeployConfig } from "../../scripts/utils/DeployUtils";
const DEFAULT_QP_CONFIG_FILE = 'QpDeployConfig.yaml';
const DEFAULT_AUTH_QUORUM_ID = '0x9f6AbbF0Ba6B5bfa27f4deb6597CC6Ec20573FDA';

const m = buildModule("PostDeployModule", (m) => {
  const config = loadConfig(process.env.QP_CONFIG_FILE || DEFAULT_QP_CONFIG_FILE) as QpDeployConfig;
  if (!config.QuantumPortalLedgerMgr || !config.QuantumPortalMinStake || !config.QuantumPortalAuthorityMgr) {
    throw new Error("Something is not set in config");
  }

  if (!config.QuantumPortalAuthorityMgr || !config.AuthorityMgrConfig?.addresses?.length) {
    throw new Error("AuthorityMgr or AuthorityMgrConfig is not set in config");
  }

  if (!config.QuantumPortalFeeConvertorDirect || !config.DirectFee) {
    throw new Error("QuantumPortalFeeConvertorDirect or DirectFee is not set in config");
  }

  const ledgerMgr = m.contractAt("QuantumPortalLedgerMgrImplUpgradeable", config.QuantumPortalLedgerMgr!  , { id: "LedgerMgr"})
  m.call(ledgerMgr, "updateMinerMinimumStake", [config.QuantumPortalMinStake!])

  const authMgr = m.contractAt("QuantumPortalAuthorityMgrUpgradeable", config.QuantumPortalAuthorityMgr!  , { id: "AuthMgr"})
  m.call(authMgr, "initializeQuoromAndRegisterFinalizer", [
    DEFAULT_AUTH_QUORUM_ID,
    1,
    config.AuthorityMgrConfig?.minSignatures!,
    0,
    config.AuthorityMgrConfig?.addresses!,
  ])

  const feeConvertor = m.contractAt("QuantumPortalFeeConverterDirectUpgradeable", config.QuantumPortalFeeConvertorDirect!  , { id: "FeeConvertor__"})
  m.call(feeConvertor, "updateFeePerByte", [config.DirectFee?.feePerByte!])
  m.call(feeConvertor, "setAdmin", [config.DirectFee?.botAddress!])

  const stake = m.contractAt("QuantumPortalStakeWithDelegateUpgradeable", config.QuantumPortalStake!  , { id: "Stake__"})
  m.call(stake, "setAdmin", [config.QuantumPortalGateway!])

  const currentChainId = hre.network.config.chainId!;
  if (config.ChainGasPrices?.[currentChainId]) {
    m.call(feeConvertor, "setChainGasPrices", [
      config.ChainGasPrices[currentChainId].chainIds,
      config.ChainGasPrices[currentChainId].feeTokenPrice,
      config.ChainGasPrices[currentChainId].gasPrice,
      config.ChainGasPrices[currentChainId].isL2,
    ])
  }

  return {
    stake,
    ledgerMgr,
    authMgr,
    feeConvertor
  }
})

export default m;
