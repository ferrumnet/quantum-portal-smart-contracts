pragma solidity ^0.8.24;
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract DummyERC20 is ERC20Burnable {
        constructor() ERC20("Dummy", "DMT") {
                _mint(msg.sender, 1000000 * 10 ** 18);
        }
}
