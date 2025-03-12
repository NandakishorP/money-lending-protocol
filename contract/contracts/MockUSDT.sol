// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDT is ERC20 {
  constructor(
    string memory name,
    string memory symbol,
    uint8 decimal
  ) ERC20(name, symbol) {
    _mint(msg.sender, 100000000 * 10 ** uint256(decimal));
  }

  function decimals() public view virtual override returns (uint8) {
    return 6; // Simulate USDT with 6 decimals
  }
  function mint(address to, uint256 amount) public {
    _mint(to, amount);
  }
}
