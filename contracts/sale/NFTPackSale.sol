// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./BaseNFTSale.sol";

contract NFTPackSale is Ownable, BaseNFTSale {
  using SafeERC20 for IERC20;

  struct Pack {
    address nft;
    uint256[] tokenIds;
    TokenStandard nftType;
    address paymentToken;
    uint256 price;
    bool enabled;
  }

  Pack[] public packs;
  address payable public feeRecipient;
  bool public allEnabled = true;

  event PackAdded(uint256 indexed price, bool indexed enabled, uint256[] indexed tokenIds);
  event PackSold(uint256 indexed packId, address indexed user);

  constructor(address payable _feeRecipient) {
    feeRecipient = _feeRecipient;
  }

  function addPacks(Pack[] memory _packs) public onlyOwner {
    for (uint256 i = 0; i < _packs.length; i++) {
      Pack memory _pack = _packs[i];
      require(_pack.price > 0, "NFTPackSale: Invalid Price!");
      require(_pack.tokenIds.length > 0, "NFTPackSale: Items must not be empty");

      packs.push();
      Pack storage pack = packs[packs.length - 1];
      pack.price = _pack.price;
      pack.enabled = _pack.enabled;
      pack.paymentToken = _pack.paymentToken;
      pack.nft = _pack.nft;
      pack.nftType = TokenStandard(_pack.nftType);

      for (uint256 j = 0; j < _pack.tokenIds.length; j++) {
        pack.tokenIds.push(_pack.tokenIds[j]);
      }

      emit PackAdded(_pack.price, _pack.enabled, _pack.tokenIds);
    }
  }

  function setPackEnabled(uint256 packId, bool enabled) external onlyOwner {
    require(packs.length > packId, "NFTPackSale: Invalid Pack Id");
    packs[packId].enabled = enabled;
  }

  function setAllEnabled(bool _enabled) external onlyOwner {
    allEnabled = _enabled;
  }

  function setPackPrice(uint256 packId, uint256 price) external onlyOwner {
    packs[packId].price = price;
  }

  function setFeeRecipient(address payable _feeRecipient) external onlyOwner {
    feeRecipient = _feeRecipient;
  }

  function getAllPacks() external view returns (Pack[] memory) {
    return packs;
  }

  function getPackInfo(uint256 packId) external view returns (Pack memory) {
    return packs[packId];
  }

  function buyPack(uint256 packId, uint256 quantity) external payable {
    Pack storage pack = packs[packId];
    require(allEnabled, "NFTPackSale: Packs are disabled!");
    require(pack.enabled, "NFTPackSale: Pack disabled!");
    require(quantity > 0, "NFTPackSale: Pack Quantity should not be zero");

    if (address(pack.paymentToken) == address(0)) {
      require(pack.price * quantity == msg.value, "NFTPackSale: Invalid amount");
      feeRecipient.transfer(pack.price * quantity);
    } else {
      require(msg.value == 0, "NFTPackSale: No eth required");
      IERC20(pack.paymentToken).safeTransferFrom(msg.sender, feeRecipient, pack.price * quantity);
    }

    for (uint256 k = 0; k < quantity; k++) {
      for (uint256 i = 0; i < pack.tokenIds.length; i++) {
        require(IERC1155(pack.nft).balanceOf(address(this), pack.tokenIds[i]) > 0, "NFTPackSale: Pack is sold");
        nftTransfer(pack.nft, uint8(pack.nftType), address(this), msg.sender, pack.tokenIds[i], 1);
      }
    }

    emit PackSold(packId, msg.sender);
  }
}
