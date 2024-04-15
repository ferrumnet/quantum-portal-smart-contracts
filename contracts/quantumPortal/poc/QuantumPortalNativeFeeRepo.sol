// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IQuantumPortalPoc.sol";
import "../../uniswap/IWETH.sol";
import "./poa/IQuantumPortalFeeConvertor.sol";
import "./IQuantumPortalNativeFeeRepo.sol";
import "foundry-contracts/contracts/common/IVersioned.sol";
import "foundry-contracts/contracts/math/FullMath.sol";
import "foundry-contracts/contracts/math/FixedPoint128.sol";
import "foundry-contracts/contracts/common/SafeAmount.sol";
import "foundry-contracts/contracts/common/WithAdmin.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @notice The quantum portal main contract for multi-chain dApps
 */
abstract contract QuantumPortalNativeFeeRepo is
    IQuantumPortalNativeFeeRepo,
    IQuantumPortalPoc,
    IVersioned,
    WithAdmin
{
    using SafeERC20 for IERC20;
    string public constant override VERSION = "000.001";
    address public weth;
    IQuantumPortalPoc portal;
    address public feeConvertor;

    function init(address _portal, address _feeConvertor) external onlyAdmin {
        portal = IQuantumPortalPoc(_portal);
        feeConvertor = _feeConvertor;
    }

    function sweepGas(address sweepTarget) external payable onlyAdmin {
        SafeAmount.safeTransferETH(sweepTarget, address(this).balance);
    }

    function sweepFrm(address sweepTarget) external onlyAdmin {
        address feeToken = portal.feeToken();
        IERC20(feeToken).safeTransfer(sweepTarget, IERC20(feeToken).balanceOf(address(this)));
    }

    function swapFee() external payable override {
        // Get the equivalent fee amount from native tokens
        // Send the fee to feeTarget
        require(msg.sender == address(portal), "QPNFR: not allowed");
        uint amount = msg.value;
        uint256 gasPrice = IQuantumPortalFeeConvertor(feeConvertor)
            .localChainGasTokenPriceX128();
        uint256 txGas = FullMath.mulDiv(
                gasPrice,
                amount,
                FixedPoint128.Q128
            );
        IERC20(portal.feeToken()).safeTransfer(portal.feeTarget(), txGas);
    }
}