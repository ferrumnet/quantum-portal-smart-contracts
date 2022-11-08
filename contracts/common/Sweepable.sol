// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract Sweepable is Ownable {
    using SafeERC20 for IERC20;
    bool public sweepFrozen;

    function freezeSweep() external onlyOwner {
        sweepFrozen = true;
    }

    function sweepToken(address token, address to, uint256 amount) external onlyOwner {
        require(!sweepFrozen, "S: Sweep is frozen");
        IERC20(token).safeTransfer(to, amount);
    }
}