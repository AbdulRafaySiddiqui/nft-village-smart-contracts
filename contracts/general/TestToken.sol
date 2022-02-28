// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// only for testing purpose
contract TestToken is ERC20 {
  constructor(string memory symbol) ERC20("$TEST", symbol) {
    _mint(msg.sender, 10000000e18);
  }

  function mint(address account, uint256 amount) external {
    _mint(account, amount);
  }
}
