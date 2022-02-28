// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./INFTVillageCardFeatures.sol";

abstract contract INFTVillageCards is INFTVillageCardFeatures, IERC1155 {}
