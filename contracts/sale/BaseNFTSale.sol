// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract BaseNFTSale is Ownable, ERC721Holder, ERC1155Holder {
  enum TokenStandard {
    ERC721,
    ERC1155
  }

  function nftTransfer(
    address nft,
    uint8 nftType,
    address from,
    address to,
    uint256 tokenId,
    uint256 amount
  ) internal {
    if (TokenStandard(nftType) == TokenStandard.ERC721) {
      IERC721(nft).safeTransferFrom(from, to, tokenId);
    } else if (TokenStandard(nftType) == TokenStandard.ERC1155) {
      IERC1155(nft).safeTransferFrom(from, to, tokenId, amount, "");
    } else {
      revert("BaseNFTSale: Unsupported TokenStandard");
    }
  }

  function withdrawNFT(
    address nft,
    uint8 nftType,
    address from,
    address to,
    uint256 tokenId,
    uint256 amount
  ) external onlyOwner {
    nftTransfer(nft, nftType, from, to, tokenId, amount);
  }
}
