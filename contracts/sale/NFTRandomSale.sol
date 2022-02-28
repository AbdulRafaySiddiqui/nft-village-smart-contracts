// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "../general/TestVRFConsumerBase.sol";
import "./BaseNFTSale.sol";

contract NFTRandomSale is Ownable, BaseNFTSale {
  using SafeERC20 for IERC20;

  //Const MAX Weight
  uint256 private constant MAX_WEIGHT = 100;
  uint256 internal totalWeight;

  uint256 internal nonce;
  uint56 public sellCount;
  uint256 public price;
  address public paymentToken;
  address public feeRecipient;
  address private nft;

  bool public enabled;

  constructor(
    address _paymentToken,
    uint256 _price,
    address _nft,
    address _feeRecipient
  ) {
    paymentToken = _paymentToken;
    price = _price;
    nft = _nft;
    feeRecipient = _feeRecipient;
    enabled = true;
  }

  //Rairty struct
  struct Rarity {
    uint8 weight;
    uint256[] tokenIds;
  }

  //public array for rarities
  Rarity[] public rarities;

  event RarityAdded(uint8 indexed weight, uint256[] tokenIds);
  event Buy(uint256 indexed tokenId, address indexed buyer);
  event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

  //Get All Rarities
  function getAllRarties() external view returns (Rarity[] memory) {
    return rarities;
  }

  function addRarities(Rarity[] memory _rarities) external onlyOwner {
    for (uint256 i = 0; i < _rarities.length; i++) {
      _addRarity(_rarities[i].weight, _rarities[i].tokenIds);
    }
  }

  //Add rarity in rarities array
  function _addRarity(uint8 _weight, uint256[] memory _tokenIds) internal {
    require(_tokenIds.length > 0, "NFTRandomSale: TokenIds must not be empty");
    totalWeight += _weight;
    require(totalWeight <= MAX_WEIGHT, "NFTRandomSale: Weight Limit exceeds");

    rarities.push();
    Rarity storage rarity = rarities[rarities.length - 1];
    rarity.weight = _weight;
    rarity.tokenIds = _tokenIds;

    emit RarityAdded(_weight, _tokenIds);
  }

  // Select Rarity
  function getRartiyProbabilityList() internal view returns (uint256[] memory) {
    uint256[] memory rarityList = new uint256[](totalWeight);
    uint256 index;
    for (uint256 i = 0; i < rarities.length; i++) {
      for (uint256 j = 0; j < rarities[i].weight; j++) {
        rarityList[index++] = i;
      }
    }
    return rarityList;
  }

  // remove the rarities where tokenId list is empty
  function updateRaritiesList(
    uint256 rarityId,
    uint256 tokenIdIndex,
    uint256 tokenId
  ) internal {
    Rarity storage rarity = rarities[rarityId];
    if (IERC1155(nft).balanceOf(address(this), tokenId) == 0) {
      //Remove selected tokenId from tokeIds list
      rarity.tokenIds[tokenIdIndex] = rarity.tokenIds[rarity.tokenIds.length - 1];
      rarity.tokenIds.pop();
    }

    // remove rarity is tokenIds are empty
    if (rarity.tokenIds.length == 0) {
      totalWeight -= rarity.weight;
      rarities[rarityId] = rarities[rarities.length - 1];
      rarities.pop();
    }
  }

  //Buy pack
  function buyPack() external payable {
    require(enabled, "NFTRandomSale: Disabled!");

    if (paymentToken == address(0)) {
      require(price == msg.value, "NFTRandomSale: Invalid amount");
      payable(feeRecipient).transfer(msg.value);
    } else {
      IERC20(paymentToken).safeTransferFrom(msg.sender, feeRecipient, price);
    }
    require(rarities.length > 0, "NFTRandomSale: Rarities length is zero");

    //randomly select rarity
    uint256[] memory rarityList = getRartiyProbabilityList();
    uint256 randomRarity = getRandomNumber(0, totalWeight);
    uint256 selectedRarityIndex = rarityList[randomRarity];
    Rarity storage rarity = rarities[selectedRarityIndex];

    //randomly select tokenId
    uint256 randomTokenIdIndex = getRandomNumber(0, rarity.tokenIds.length - 1);
    uint256 selectedTokenId = rarity.tokenIds[randomTokenIdIndex];
    nftTransfer(nft, uint8(TokenStandard.ERC1155), address(this), msg.sender, selectedTokenId, 1);

    updateRaritiesList(selectedRarityIndex, randomTokenIdIndex, selectedTokenId);

    sellCount++;

    emit Buy(selectedTokenId, msg.sender);
  }

  function setPackPrice(uint256 _price) external onlyOwner {
    price = _price;
  }

  function setPaymentToken(address _paymentToken) external onlyOwner {
    paymentToken = _paymentToken;
  }

  function setNftAddress(address _nft) external onlyOwner {
    nft = _nft;
  }

  function setFeeRecipient(address _account) external onlyOwner {
    feeRecipient = _account;
  }

  function setEnabled(bool _enabled) external onlyOwner {
    enabled = _enabled;
  }

  function getRandomNumber(uint256 min, uint256 max) internal returns (uint256) {
    if (max == 0) return 0;
    return (uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, msg.sender, nonce++))) % max) + min;
  }
}
