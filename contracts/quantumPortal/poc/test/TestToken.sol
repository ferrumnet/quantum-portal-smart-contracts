// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract TestToken is ERC20Burnable, Ownable {
	constructor() ERC20("Dummy", "DMT") Ownable(tx.origin) {
		_mint(tx.origin, 1_000_000_000 ether);
	}

	function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
