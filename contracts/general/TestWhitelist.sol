// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract TestWhitelist {
  bool returnValue;

  function toggle() external {
    returnValue = !returnValue;
  }

  function userContribution(address) external view returns (uint256) {
    return returnValue ? 1 : 0;
  }
}
