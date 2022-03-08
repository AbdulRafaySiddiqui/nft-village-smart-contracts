// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract WithdrawAccidentallySentTokens is Ownable {
  using SafeERC20 for IERC20;

  function drainAccidentallySentTokens(
    IERC20 token,
    address recipient,
    uint256 amount
  ) external onlyOwner {
    token.safeTransfer(recipient, amount);
  }

  function withdrawAccidentallySentEth(address payable recipient, uint256 amount) external onlyOwner {
    recipient.transfer(amount);
  }
}
