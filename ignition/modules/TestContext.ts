import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import { Wei } from 'foundry-contracts/dist/test/common/Utils';
import { ZeroAddress } from "ethers";

const TEST_PKS = [
	'0x0123456789012345678901234567890123456789012345678901234567890123',
	'0x0123456789012345678901234567890123456789012345678901234567890124',
	'0x0123456789012345678901234567890123456789012345678901234567890125',
	'0x0123456789012345678901234567890123456789012345678901234567890126',
	'0x0123456789012345678901234567890123456789012345678901234567890127',
	'0x0123456789012345678901234567890123456789012345678901234567890128',
];

const TEST_WALLETS = [ // Corresponds to above private keys
    '0x14791697260E4c9A71f18484C9f997B308e59325',
    '0x4C42F75ceae7b0CfA9588B940553EB7008546C29',
    '0xD588307388250D0aC7aB33E0eEDbd31891F3062d',
    '0x223599f7AbCacC52bd94BDcf74cb5165Cf926cFf',
    '0x6C5cC185Ac632Ff168CC4a941be8ea1Bbc485216',
    '0x85A5F7da41C7596Cd0A81969E0fDbe671c20B24a'
]

const deployModule = buildModule("DeployModule", (m) => {
	const testGatewayAddress = ZeroAddress // Pass zero address for gateway just for tests
	const owner = m.getAccount(0) // Same address for owner and admin
	const acc1 = m.getAccount(1)
	const acc2 = m.getAccount(2)
	
	//------------- LedgerManagerTest ----------------//
    const mgr1Impl = m.contract("QuantumPortalLedgerMgrUpgradeableTest", [26000], { id: "QPLedgerMgr1"})
	const mgr2Impl = m.contract("QuantumPortalLedgerMgrUpgradeableTest", [2], { id: "QPLedgerMgr2"})

	let initializeCalldata: any = m.encodeFunctionCall(mgr1Impl, "initialize", [
		owner,
		owner,
		testGatewayAddress
	]);

	const mgr1Proxy = m.contract("ERC1967Proxy", [mgr1Impl, initializeCalldata], { id: "Mgr1Proxy"})
	const mgr2Proxy = m.contract("ERC1967Proxy", [mgr2Impl, initializeCalldata], { id: "Mgr2Proxy"})

	const mgr1 = m.contractAt("QuantumPortalLedgerMgrUpgradeableTest", mgr1Proxy, { id: "Mgr1"})
	const mgr2 = m.contractAt("QuantumPortalLedgerMgrUpgradeableTest", mgr2Proxy, { id: "Mgr2"})

	const chainId1 = m.call(mgr1Impl, "realChainId")
    const chainId2 = 2;

	m.call(mgr1, "updateMinerMinimumStake", [Wei.from('10')])
	m.call(mgr2, "updateMinerMinimumStake", [Wei.from('10')])

	//------------- QuantumPortalPoc -------------------//
	const poc1Impl = m.contract("QuantumPortalPocUpgradeableTest", [26000], { id: "QPPoc1"})
	const poc2Impl = m.contract("QuantumPortalPocUpgradeableTest", [2], { id: "QPPoc2"})

	const poc1Proxy = m.contract("ERC1967Proxy", [poc1Impl, initializeCalldata], { id: "Poc1Proxy"})
	const poc2Proxy = m.contract("ERC1967Proxy", [poc2Impl, initializeCalldata], { id: "Poc2Proxy"})

	const poc1 = m.contractAt("QuantumPortalPocUpgradeableTest", poc1Proxy, { id: "Poc1"})
	const poc2 = m.contractAt("QuantumPortalPocUpgradeableTest", poc2Proxy, { id: "Poc2"})

	//-------------- Authority Managers ----------------//
	const authMgrImpl = m.contract("QuantumPortalAuthorityMgrUpgradeable", [], { id: "QPAuthorityMgr1"})

	initializeCalldata = m.encodeFunctionCall(authMgrImpl, "initialize", [
		mgr1,
		poc1,
		acc1,
		acc1,
		testGatewayAddress
	], { id: "AuthMgr1Initialize"});
	const authMgr1Proxy = m.contract("ERC1967Proxy", [authMgrImpl, initializeCalldata], { id: "AuthMgr1Proxy"})

	initializeCalldata = m.encodeFunctionCall(authMgrImpl, "initialize", [
		mgr2,
		poc2,
		acc2,
		acc2,
		testGatewayAddress
	], { id: "AuthMgr2Initialize"});
	const authMgr2Proxy = m.contract("ERC1967Proxy", [authMgrImpl, initializeCalldata], { id: "AuthMgr2Proxy"})

	const authMgr1 = m.contractAt("QuantumPortalAuthorityMgrUpgradeable", authMgr1Proxy, { id: "AuthMgr1"}, )
	const authMgr2 = m.contractAt("QuantumPortalAuthorityMgrUpgradeable", authMgr2Proxy, { id: "AuthMgr2"})

	//-------------- TestToken ----------------//
	const testFeeToken = m.contract("TestToken", [])

	// ------ Fee Converter Direct ------------//
	const feeConverterImpl = m.contract("QuantumPortalFeeConverterDirectUpgradeable", [], { id: "FeeConverterImpl"})
	initializeCalldata = m.encodeFunctionCall(feeConverterImpl, "initialize", [
		testGatewayAddress
	]);
	const feeConverterProxy = m.contract("ERC1967Proxy", [feeConverterImpl, initializeCalldata], { id: "FeeConverterProxy"})
	const feeConverter = m.contractAt("QuantumPortalFeeConverterDirectUpgradeable", feeConverterProxy, { id: "FeeConverter"})

	m.call(feeConverter, "updateFeePerByte", [Wei.from('0.001')])

	// -------------- Staking -----------------//
	const stakingImpl = m.contract("QuantumPortalStakeWithDelegateUpgradeable", [], { id: "StakingImpl"})
	let stakinginitializeCalldata = m.encodeFunctionCall(stakingImpl, "initialize(address,address,address,address)", [
		testFeeToken,
		authMgr1,
		ZeroAddress,
		testGatewayAddress
	]);
	const stakingProxy = m.contract("ERC1967Proxy", [stakingImpl, stakinginitializeCalldata], { id: "StakingProxy"})
	const staking = m.contractAt("QuantumPortalStakeWithDelegateUpgradeable", stakingProxy, { id: "Staking"})

	// ----------- Mining Manager --------------//
	const minerMgrImpl = m.contract("QuantumPortalMinerMgrUpgradeable", [], { id: "MinerMgrImpl"})
	initializeCalldata = m.encodeFunctionCall(minerMgrImpl, "initialize", [
		staking,
		poc1,
		mgr1,
		testGatewayAddress
	], { id: "MinerMgrInitialize1"});
	const minerMgr1Proxy = m.contract("ERC1967Proxy", [minerMgrImpl, initializeCalldata], { id: "MinerMgrProxy1"})
	initializeCalldata = m.encodeFunctionCall(minerMgrImpl, "initialize", [
		staking,
		poc2,
		mgr2,
		testGatewayAddress
	], { id: "MinerMgrInitialize2"});
	const minerMgr2Proxy = m.contract("ERC1967Proxy", [minerMgrImpl, initializeCalldata], { id: "MinerMgrProxy2"})

	const minerMgr1 = m.contractAt("QuantumPortalMinerMgrUpgradeable", minerMgr1Proxy, { id: "MinerMgr1"})
	const minerMgr2 = m.contractAt("QuantumPortalMinerMgrUpgradeable", minerMgr2Proxy, { id: "MinerMgr2"})

	// --------- Authority Setup ------------//
	m.call(authMgr1, "initializeQuorum", [owner, 1, 1, 0, [TEST_WALLETS[0]]], {from: acc1})
	m.call(authMgr2, "initializeQuorum", [owner, 1, 1, 0, [TEST_WALLETS[0], TEST_WALLETS[1]]], {from: acc2})
	m.call(mgr1, "updateAuthorityMgr", [authMgr1])
	m.call(mgr1, "updateMinerMgr", [minerMgr1])
	m.call(mgr1, "updateFeeConvertor", [feeConverter])
	m.call(minerMgr1, "updateRemotePeers", [[chainId2], [minerMgr2]])
	m.call(mgr2, "updateAuthorityMgr", [authMgr2])
	m.call(mgr2, "updateMinerMgr", [minerMgr2])
	m.call(mgr2, "updateFeeConvertor", [feeConverter])
	m.call(minerMgr2, "updateRemotePeers", [[31337], [minerMgr1]]) // TODO: Figure out how to pass chainId1 variable

	// ------------- QP State --------------//
	// const qpStateImpl = m.contract("QuantumPortalStateUpgradeable")
	// initializeCalldata = m.encodeFunctionCall(qpStateImpl, "initialize", [
	// 	owner,
	// 	owner,
	// 	testGatewayAddress
	// ]);
	// const qpState1Proxy = m.contract("ERC1967Proxy", [qpStateImpl, initializeCalldata], { id: "QPState1Proxy"})
	// const qpState2Proxy = m.contract("ERC1967Proxy", [qpStateImpl, initializeCalldata], { id: "QPState2Proxy"})

	// const qpState1 = m.contractAt("QuantumPortalStateUpgradeable", qpState1Proxy, { id: "QPState1"})
	// const qpState2 = m.contractAt("QuantumPortalStateUpgradeable", qpState2Proxy, { id: "QPState2"})

	// -------------- Setup ---------------//
	// m.call(poc1, "setManager", [mgr1, qpState1])
	// m.call(poc1, "updateFeeTarget", [])
	// m.call(poc1, "setFeeToken", [testFeeToken])
	// m.call(minerMgr1, "updateBaseToken", [testFeeToken])
	// m.call(poc2, "setManager", [mgr2, qpState2])
	// m.call(poc2, "updateFeeTarget", [])
	// m.call(poc2, "setFeeToken", [testFeeToken])
	// m.call(minerMgr2, "updateBaseToken", [testFeeToken])
	// m.call(mgr1, "updateLedger", [poc1])
	// m.call(mgr1, "updateState", [qpState1])
	// m.call(mgr2, "updateLedger", [poc2])
	// m.call(mgr2, "updateState", [qpState2])

	return {
        mgr1,
		mgr2,
		poc1,
		poc2,
		authMgr1,
		authMgr2,
		testFeeToken,
		feeConverter,
		staking,
		minerMgr1,
		minerMgr2,
    }
})

export default deployModule;
