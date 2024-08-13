// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";


contract TestToken is ERC20Burnable {
	constructor() ERC20("Dummy", "DMT") {
		_mint(msg.sender, 1_000_000 ether);
	}
}
