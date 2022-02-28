// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IFeeReceiver {
  function onFeeReceived(address token, uint256 amount) external payable;
}
