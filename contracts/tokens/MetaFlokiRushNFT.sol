// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./NFTVillageERC1155.sol";

contract MetaFlokiRushNFT is NFTVillageERC1155 {
  constructor(string memory _uri) NFTVillageERC1155("MetaFlokiRushNFT", "FLOKIR", _uri) {}
}
