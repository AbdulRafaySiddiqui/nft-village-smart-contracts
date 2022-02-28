// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IFeeReceiver.sol";
import "../interfaces/IDEXRouter.sol";

contract NFTVillageChiefFeeReceiver is Ownable, IFeeReceiver {
  event FeeReceived(address token, uint256 amount);

  function onFeeReceived(address token, uint256 amount) external payable override {
    if (token == address(0)) {
      payable(owner()).transfer(address(this).balance);
    } else {
      IERC20(token).transfer(owner(), amount);
    }
    emit FeeReceived(token, amount);
  }

  function drainAccidentallySentTokens(
    IERC20 token,
    address recipient,
    uint256 amount
  ) external onlyOwner {
    token.transfer(recipient, amount);
  }
}
