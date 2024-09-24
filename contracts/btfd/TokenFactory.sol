pragma solidity ^0.8.24;

import "./ITokenFactory.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "./Bitcoin.sol";
import "./QpErc20Token.sol";
import "./WalletRegistration.sol";
import "./FeeStore.sol";

import "hardhat/console.sol";

error OnlyQpToken();

contract TokenFactory is ITokenFactory, Ownable {
    address public runeImplementation;
    UpgradeableBeacon public runeBeacon;
    address public btcImplementation;
    UpgradeableBeacon public btcBeacon;
    address public btc;
    address public override portal;
    address public override feeConvertor; // Has the price for fee VS native token
    address public override feeStore; // Stores fee for rune transactions
    address public override qpWallet;
    address public override qpRuneWallet;
    address public override registration;
    mapping (bytes32 => address) public runeTokens;
    mapping (address => bytes32) public runeTokensByAddress;

    event Deployed(address impl, address deped, address beacon);

    constructor(address _portal, address _feeConvertor, address _qpWallet, address _qpRuneWallet) Ownable(msg.sender) {
        runeImplementation = address(new QpErc20Token{salt: bytes32(0x0)}());
        runeBeacon = new UpgradeableBeacon{salt: bytes32(uint256(0x1))}(runeImplementation, address(this));
        btcImplementation = address(new Bitcoin{salt: bytes32(0x0)}());
        btcBeacon = new UpgradeableBeacon{salt: bytes32(uint256(0x2))}(btcImplementation, address(this));
        deployBitcoin();
        registration = address(new WalletRegistration{salt: bytes32(0x0)}());
        feeStore = address(new FeeStore{salt: bytes32(0x0)}());
        portal = _portal;
        feeConvertor = _feeConvertor;
        qpWallet = _qpWallet;
        qpWallet = _qpRuneWallet;
    }

    function updatePortal(address _portal, address _feeConvertor, address _qpWallet, address _qpRuneWallet) external onlyOwner {
        portal = _portal;
        feeConvertor = _feeConvertor;
        qpWallet = _qpWallet;
        qpWallet = _qpRuneWallet;
    }

    function upgradeImplementations(address newRuneImpl, address newBtcImpl, address _registration) external onlyOwner {
        runeBeacon.upgradeTo(newRuneImpl);
        runeImplementation = newRuneImpl;
        btcBeacon.upgradeTo(newBtcImpl);
        btcImplementation = newBtcImpl;
        registration = _registration;
    }

    function getRuneTokenAddress(
        uint runeId,
        uint version
    ) external view returns(address) {
        bytes32 salt = keccak256(abi.encode(runeId, version));
        return runeTokens[salt];
    }

    function deployRuneToken(
        uint runeId,
        uint64 version,
        string calldata name,
        string calldata symbol,
        uint8 decimals,
        uint totalSupply,
        bytes32 deployTxId
    ) external {
        // Deploy beacon proxy token...
        // then init(...)
        // So that no one can deploy the token with invalid name/decimals, etc.
        // The token's init function must validate the metadata (name, symbol, etc)
        bytes32 salt = keccak256(abi.encode(runeId, version));
        BeaconProxy dep = new BeaconProxy{salt: salt}(address(runeBeacon), new bytes(0));
        QpErc20Token(address(dep)).initialize(
            runeId,
            version,
            name,
            symbol,
            decimals,
            totalSupply,
            deployTxId
        );
        runeTokens[salt] = address(dep);
        runeTokensByAddress[address(dep)] = salt;
        emit Deployed(runeImplementation, address(dep), address(runeBeacon));
    }

    /**
     * @notice Proxies runeToken call to the Fee Store
     */
    function feeStoreCollectFee(
        bytes32 txId) external returns (uint) {
        if (runeTokensByAddress[msg.sender] == 0x0) { revert OnlyQpToken(); }
        return FeeStore(feeStore).collectFee(txId);
    }

    function feeStoreSweepToken(address token, uint amount, address to) external override {
        FeeStore(feeStore).sweepToken(token, amount, to);
    }

    function deployBitcoin() internal {
        btc = address(new BeaconProxy{salt: bytes32(uint256(0x11011))}(address(btcBeacon), new bytes(0)));
        runeTokensByAddress[address(btc)] = bytes32(uint256(0x11011));
        Bitcoin(btc).initialize();
    }
}