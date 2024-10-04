// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract FeeToken is ERC20, Ownable {
    constructor() ERC20("FeeToken", "FT") Ownable(tx.origin) {
        _mint(tx.origin, 1000000000 ether);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
