// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVersioned} from "foundry-contracts/contracts/contracts/common/IVersioned.sol";
import {FullMath} from "foundry-contracts/contracts/contracts/math/FullMath.sol";
import {FixedPoint128} from "foundry-contracts/contracts/contracts/math/FixedPoint128.sol";
import {SafeAmount} from "foundry-contracts/contracts/contracts/common/SafeAmount.sol";
import {WithAdminUpgradeable} from "foundry-contracts/contracts/contracts-upgradeable/common/WithAdminUpgradeable.sol";
import {IQuantumPortalPoc} from "./IQuantumPortalPoc.sol";
import {IWETH} from "../../uniswap/IWETH.sol";
import {IQuantumPortalFeeConvertor} from "./poa/IQuantumPortalFeeConvertor.sol";
import {IQuantumPortalNativeFeeRepo} from "./IQuantumPortalNativeFeeRepo.sol";


/**
 * @notice The quantum portal main contract for multi-chain dApps
 */
abstract contract QuantumPortalNativeFeeRepoUpgradeable is
    IQuantumPortalNativeFeeRepo,
    IVersioned,
    WithAdminUpgradeable
{
    using SafeERC20 for IERC20;
    string public constant override VERSION = "000.001";

    /// @custom:storage-location erc7201:ferrum.storage.quantumportalnativefeerepo.001
    struct QuantumPortalNativeFeeRepoStorageV001 {
        address weth;
        address feeConvertor;
        IQuantumPortalPoc portal;
    }

    // keccak256(abi.encode(uint256(keccak256("ferrum.storage.quantumportalnativefeerepo.001")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant QuantumPortalNativeFeeRepoStorageV001Location = 0xae7fdbb2d201f5b87e85ad14aa609294a809885fb99c06bf8a86920d30693b00;

    function __QuantumPortalNativeFeeRepo_init(
        address _portal,
        address _feeConvertor,
        address initialOwner,
        address initialAdmin
    ) internal onlyInitializing {
        __WithAdmin_init(initialOwner, initialAdmin);
        __QuantumPortalNativeFeeRepo_init_unchained(_portal, _feeConvertor);
    }

    function __QuantumPortalNativeFeeRepo_init_unchained(address _portal, address _feeConvertor) internal onlyInitializing {
        QuantumPortalNativeFeeRepoStorageV001 storage $ = _getQuantumPortalNativeFeeRepoStorageV001();
        $.portal = IQuantumPortalPoc(_portal);
        $.feeConvertor = _feeConvertor;
    }

    function feeConvertor() external view returns (address) {
        return _getQuantumPortalNativeFeeRepoStorageV001().feeConvertor;
    }

    function _getQuantumPortalNativeFeeRepoStorageV001() internal pure returns (QuantumPortalNativeFeeRepoStorageV001 storage $) {
        assembly {
            $.slot := QuantumPortalNativeFeeRepoStorageV001Location
        }
    }

    function sweepGas(address sweepTarget) external payable onlyAdmin {
        SafeAmount.safeTransferETH(sweepTarget, address(this).balance);
    }

    function sweepFrm(address sweepTarget) external onlyAdmin {
        QuantumPortalNativeFeeRepoStorageV001 storage $ = _getQuantumPortalNativeFeeRepoStorageV001();
        address feeToken = $.portal.feeToken();
        IERC20(feeToken).safeTransfer(sweepTarget, IERC20(feeToken).balanceOf(address(this)));
    }

    function swapFee() external payable override {
        QuantumPortalNativeFeeRepoStorageV001 storage $ = _getQuantumPortalNativeFeeRepoStorageV001();
        // Get the equivalent fee amount from native tokens
        // Send the fee to feeTarget
        require(msg.sender == address($.portal), "QPNFR: not allowed");
        uint amount = msg.value;
        uint256 frmPrice = IQuantumPortalFeeConvertor($.feeConvertor).localChainGasTokenPrice();
        uint256 frmAmount = frmPrice * amount;
        IERC20($.portal.feeToken()).safeTransfer($.portal.feeTarget(), frmAmount);
    }
}

contract QuantumPortalNativeFeeRepoBasicUpgradeable is QuantumPortalNativeFeeRepoUpgradeable {
    function initialize(address _portal, address _feeConvertor, address initialOwner, address initialAdmin) public virtual initializer {
        QuantumPortalNativeFeeRepoUpgradeable.__QuantumPortalNativeFeeRepo_init(_portal, _feeConvertor, initialOwner, initialAdmin);
    }
}