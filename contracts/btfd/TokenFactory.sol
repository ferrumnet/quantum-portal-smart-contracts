pragma solidity ^0.8.24;

import "./ITokenFactory.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UUPSUpgradeable, Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IVersioned} from "foundry-contracts/contracts/contracts/common/IVersioned.sol";
import "./Bitcoin.sol";
import "./QpErc20Token.sol";
import "./WalletRegistration.sol";
import "./FeeStore.sol";

import "hardhat/console.sol";

error OnlyQpToken();

contract TokenFactory is
    ITokenFactory,
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    IVersioned {
    string public constant override VERSION = "000.001";
    struct TokenFactoryStorageV001 {
        address runeImplementation;
        UpgradeableBeacon runeBeacon;
        address btcImplementation;
        UpgradeableBeacon btcBeacon;
        address btc;
        address portal;
        address feeConvertor; // Has the price for fee VS native token
        address feeStore; // Stores fee for rune transactions
        address qpWallet;
        address qpRuneWallet;
        address registration;
        mapping (bytes32 => address) runeTokens;
        mapping (address => bytes32) runeTokensByAddress;
    }

    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.TokenFactory.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TokenFactoryStorageV001Location = 0x86b1ac319d039482847cca0b2f4f5ab27bfdb4a12864324807f7819c61b01d00;

    function _getTokenFactoryStorageV001() internal pure returns (TokenFactoryStorageV001 storage $) {
        assembly {
            $.slot := TokenFactoryStorageV001Location
        }
    }

    function initialize(address _portal, address _feeConvertor, address _qpWallet, address _qpRuneWallet, address initialOwner
    ) public initializer {
        __TokenFactory_init(_portal, _feeConvertor, _qpWallet, _qpRuneWallet);
        __Ownable_init(initialOwner);
    }

    function __TokenFactory_init(address _portal, address _feeConvertor, address _qpWallet, address _qpRuneWallet
    ) internal onlyInitializing {
        TokenFactoryStorageV001 storage $ = _getTokenFactoryStorageV001();
        $.runeImplementation = address(new QpErc20Token{salt: bytes32(0x0)}());
        $.runeBeacon = new UpgradeableBeacon{salt: bytes32(uint256(0x1))}($.runeImplementation, address(this));
        $.btcImplementation = address(new Bitcoin{salt: bytes32(0x0)}());
        $.btcBeacon = new UpgradeableBeacon{salt: bytes32(uint256(0x2))}($.btcImplementation, address(this));
        deployBitcoin();
        $.registration = address(new WalletRegistration{salt: bytes32(0x0)}());
        $.feeStore = address(new FeeStore{salt: bytes32(0x0)}());
        $.portal = _portal;
        $.feeConvertor = _feeConvertor;
        $.qpWallet = _qpWallet;
        $.qpWallet = _qpRuneWallet;
    }

    function __TokenFactory_init_unchained() internal onlyInitializing {}

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    event Deployed(address impl, address deped, address beacon);

    function runeImplementation() external view returns (address) {
        return _getTokenFactoryStorageV001().runeImplementation;
    }

    function runeBeacon() external view returns (address) {
        return address(_getTokenFactoryStorageV001().runeBeacon);
    }

    function btcImplementation() external view returns (address) {
        return _getTokenFactoryStorageV001().btcImplementation;
    }

    function btcBeacon() external view returns (address) {
        return address(_getTokenFactoryStorageV001().btcBeacon);
    }

    function btc() external view returns (address) {
        return _getTokenFactoryStorageV001().btc;
    }

    function portal() external override view returns (address) {
        return _getTokenFactoryStorageV001().portal;
    }

    function feeConvertor() external override view returns (address) {
        return _getTokenFactoryStorageV001().feeConvertor;
    }

    function feeStore() external override view returns (address) {
        return _getTokenFactoryStorageV001().feeStore;
    }

    function qpWallet() external override view returns (address) {
        return _getTokenFactoryStorageV001().qpWallet;
    }

    function qpRuneWallet() external override view returns (address) {
        return _getTokenFactoryStorageV001().qpRuneWallet;
    }

    function registration() external override view returns (address) {
        return _getTokenFactoryStorageV001().registration;
    }

    function runeTokens(bytes32 salt) external view returns (address) {
        return _getTokenFactoryStorageV001().runeTokens[salt];
    }

    function runeTokensByAddress(address addr) external view returns (bytes32) {
        return _getTokenFactoryStorageV001().runeTokensByAddress[addr];
    }

    function updatePortal(address _portal, address _feeConvertor, address _qpWallet, address _qpRuneWallet) external onlyOwner {
        TokenFactoryStorageV001 storage $ = _getTokenFactoryStorageV001();
        $.portal = _portal;
        $.feeConvertor = _feeConvertor;
        $.qpWallet = _qpWallet;
        $.qpWallet = _qpRuneWallet;
    }

    function upgradeImplementations(address newRuneImpl, address newBtcImpl, address _registration) external onlyOwner {
        TokenFactoryStorageV001 storage $ = _getTokenFactoryStorageV001();
        $.runeBeacon.upgradeTo(newRuneImpl);
        $.runeImplementation = newRuneImpl;
        $.btcBeacon.upgradeTo(newBtcImpl);
        $.btcImplementation = newBtcImpl;
        $.registration = _registration;
    }

    function getRuneTokenAddress(
        uint runeId,
        uint version
    ) external view returns(address) {
        bytes32 salt = keccak256(abi.encode(runeId, version));
        TokenFactoryStorageV001 storage $ = _getTokenFactoryStorageV001();
        return $.runeTokens[salt];
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
        TokenFactoryStorageV001 storage $ = _getTokenFactoryStorageV001();
        bytes32 salt = keccak256(abi.encode(runeId, version));
        BeaconProxy dep = new BeaconProxy{salt: salt}(address($.runeBeacon), new bytes(0));
        QpErc20Token(address(dep)).initialize(
            runeId,
            version,
            name,
            symbol,
            decimals,
            totalSupply,
            deployTxId
        );
        
        $.runeTokens[salt] = address(dep);
        $.runeTokensByAddress[address(dep)] = salt;
        emit Deployed($.runeImplementation, address(dep), address($.runeBeacon));
    }

    /**
     * @notice Proxies runeToken call to the Fee Store
     */
    function feeStoreCollectFee(
        bytes32 txId) external returns (uint) {
        TokenFactoryStorageV001 storage $ = _getTokenFactoryStorageV001();
        if ($.runeTokensByAddress[msg.sender] == 0x0) { revert OnlyQpToken(); }
        return FeeStore($.feeStore).collectFee(txId);
    }

    function feeStoreSweepToken(address token, uint amount, address to) external override {
        TokenFactoryStorageV001 storage $ = _getTokenFactoryStorageV001();
        FeeStore($.feeStore).sweepToken(token, amount, to);
    }

    function deployBitcoin() internal {
        TokenFactoryStorageV001 storage $ = _getTokenFactoryStorageV001();
        $.btc = address(new BeaconProxy{salt: bytes32(uint256(0x11011))}(address($.btcBeacon), new bytes(0)));
        $.runeTokensByAddress[address($.btc)] = bytes32(uint256(0x11011));
        Bitcoin($.btc).initialize();
    }
}