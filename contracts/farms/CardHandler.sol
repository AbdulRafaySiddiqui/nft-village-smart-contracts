// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/INFTVillageCards.sol";
import "../interfaces/ICardHandler.sol";
import "../general/BaseStructs.sol";

contract CardHandler is BaseStructs, Ownable, ERC721Holder, ERC1155Holder, ICardHandler {
  address public nftVillageChief;
  address public projectHandler;

  bool _inDeposit;

  event ProjectHandlerUpdated(address indexed oldProjectHandler, address indexed newProjectHandler);

  modifier inDeposit() {
    _inDeposit = true;
    _;
    _inDeposit = false;
  }
  modifier onlyProjectHandler() {
    require(msg.sender == projectHandler, "CardHandler: Only ProjectHandler!");
    _;
  }
  modifier onlyNFTVillageChief() {
    require(msg.sender == nftVillageChief, "CardHandler: Only NFTVillageCard!");
    _;
  }

  INFTVillageCards[] public poolcards;
  mapping(uint256 => mapping(uint256 => mapping(address => NftDepositInfo))) userNftInfo;
  mapping(uint256 => mapping(uint256 => NftDeposit[])) public poolRequiredCards;

  constructor(address _chief) {
    require(_chief != address(0), "CardHandler: NFTVillageChief zero address");
    nftVillageChief = _chief;
  }

  function setProjectHandler(address _projectHandler) external override onlyNFTVillageChief {
    emit ProjectHandlerUpdated(projectHandler, _projectHandler);
    projectHandler = _projectHandler;
  }

  function ERC721Transferfrom(
    address token,
    address from,
    address to,
    uint256 tokenId
  ) external override onlyNFTVillageChief {
    IERC721(token).safeTransferFrom(from, to, tokenId);
  }

  function ERC1155Transferfrom(
    address token,
    address from,
    address to,
    uint256 tokenId,
    uint256 amount
  ) external override onlyNFTVillageChief {
    IERC1155(token).safeTransferFrom(from, to, tokenId, amount, "");
  }

  function getUserCardsInfo(
    uint256 projectId,
    uint256 poolId,
    address account
  ) external view override returns (NftDepositInfo memory) {
    return userNftInfo[projectId][poolId][account];
  }

  function getPoolRequiredCards(uint256 projectId, uint256 poolId)
    external
    view
    override
    returns (NftDeposit[] memory)
  {
    return poolRequiredCards[projectId][poolId];
  }

  function setPoolCard(uint256 _projectId, INFTVillageCards _poolcard) external override onlyProjectHandler {
    if (poolcards.length > _projectId) poolcards[_projectId] = _poolcard;
    else poolcards.push(_poolcard);
  }

  function addPoolRequiredCards(
    uint256 _projectId,
    uint256 _poolId,
    NftDeposit[] calldata _requiredCards
  ) external override onlyProjectHandler {
    for (uint256 i = 0; i < _requiredCards.length; i++) {
      poolRequiredCards[_projectId][_poolId].push(_requiredCards[i]);
    }
  }

  function useCard(
    address user,
    uint8 cardType,
    uint256 projectId,
    uint256 poolId,
    NftDeposit[] calldata cards
  ) external override onlyNFTVillageChief inDeposit returns (uint256) {
    if (CardType(cardType) == CardType.REQUIRED) useRequiredCard(user, projectId, poolId);
    else if (CardType(cardType) == CardType.FEE_DISCOUNT) return useFeeCard(user, projectId, poolId, cards);
    else if (CardType(cardType) == CardType.HARVEST_RELIEF) return useHarvestCard(user, projectId, poolId, cards);
    else if (CardType(cardType) == CardType.MULTIPLIER) return useMultiplierCard(user, projectId, poolId, cards);
    return 0;
  }

  function withdrawCard(
    address user,
    uint8 cardType,
    uint256 projectId,
    uint256 poolId,
    NftDeposit[] calldata cards
  ) external override onlyNFTVillageChief returns (uint256) {
    if (CardType(cardType) == CardType.REQUIRED) withdrawRequiredCard(user, projectId, poolId);
    else if (CardType(cardType) == CardType.FEE_DISCOUNT) withdrawFeeCard(user, projectId, poolId);
    else if (CardType(cardType) == CardType.HARVEST_RELIEF) return withdrawHarvestCard(user, projectId, poolId, cards);
    else if (CardType(cardType) == CardType.MULTIPLIER) return withdrawMultiplierCard(user, projectId, poolId, cards);
    return 0;
  }

  function useRequiredCard(
    address user,
    uint256 projectId,
    uint256 poolId
  ) private {
    INFTVillageCards poolCards = poolcards[projectId];

    NftDeposit[] storage _userNft = userNftInfo[projectId][poolId][user].required;
    NftDeposit[] storage _requiredCards = poolRequiredCards[projectId][poolId];
    if (_userNft.length == _requiredCards.length) return; // required cards are already deposited, we can move on

    for (uint256 i = 0; i < _requiredCards.length; i++) {
      poolCards.safeTransferFrom(user, address(this), _requiredCards[i].tokenId, _requiredCards[i].amount, "");
      _userNft.push(_requiredCards[i]);
    }
  }

  function useFeeCard(
    address user,
    uint256 projectId,
    uint256 poolId,
    NftDeposit[] memory cards
  ) private returns (uint256) {
    INFTVillageCards poolCards = poolcards[projectId];

    uint256 feeDiscount;
    NftDeposit[] storage _userNft = userNftInfo[projectId][poolId][user].feeDiscount;
    for (uint256 i = 0; i < cards.length; i++) {
      poolCards.safeTransferFrom(user, address(this), cards[i].tokenId, cards[i].amount, "");
      _userNft.push(cards[i]);
      feeDiscount += poolCards.getFeeDiscount(cards[i].tokenId) * cards[i].amount;
    }
    return feeDiscount;
  }

  function useHarvestCard(
    address user,
    uint256 projectId,
    uint256 poolId,
    NftDeposit[] memory cards
  ) private returns (uint256) {
    INFTVillageCards poolCards = poolcards[projectId];

    NftDeposit[] storage _userNft = userNftInfo[projectId][poolId][user].harvest;
    uint256 harvestRelief;
    for (uint256 i = 0; i < cards.length; i++) {
      poolCards.safeTransferFrom(user, address(this), cards[i].tokenId, cards[i].amount, "");
      _userNft.push(cards[i]);
      harvestRelief += poolCards.getHarvestRelief(cards[i].tokenId) * cards[i].amount;
    }
    return harvestRelief;
  }

  function useMultiplierCard(
    address user,
    uint256 projectId,
    uint256 poolId,
    NftDeposit[] memory cards
  ) private returns (uint256) {
    INFTVillageCards poolCards = poolcards[projectId];

    NftDeposit[] storage _userNft = userNftInfo[projectId][poolId][user].multiplier;
    uint256 multiplier;
    for (uint256 i = 0; i < cards.length; i++) {
      poolCards.safeTransferFrom(user, address(this), cards[i].tokenId, cards[i].amount, "");
      _userNft.push(cards[i]);
      multiplier += poolCards.getMultiplier(cards[i].tokenId) * cards[i].amount;
    }
    return multiplier;
  }

  function withdrawRequiredCard(
    address user,
    uint256 projectId,
    uint256 poolId
  ) private {
    INFTVillageCards poolCards = poolcards[projectId];

    NftDeposit[] storage cards = userNftInfo[projectId][poolId][user].required;
    for (uint256 i = 0; i < cards.length; i++)
      poolCards.safeTransferFrom(address(this), user, cards[i].tokenId, cards[i].amount, "");
    delete userNftInfo[projectId][poolId][user].required;
  }

  function withdrawFeeCard(
    address user,
    uint256 projectId,
    uint256 poolId
  ) private returns (uint256) {
    INFTVillageCards poolCards = poolcards[projectId];

    NftDeposit[] storage cards = userNftInfo[projectId][poolId][user].feeDiscount;
    uint256 feeDiscount;
    for (uint256 i = 0; i < cards.length; i++) {
      feeDiscount += poolCards.getFeeDiscount(cards[i].tokenId) * cards[i].amount;
      poolCards.safeTransferFrom(address(this), user, cards[i].tokenId, cards[i].amount, "");
    }
    delete userNftInfo[projectId][poolId][user].feeDiscount;
    return feeDiscount;
  }

  function withdrawHarvestCard(
    address user,
    uint256 projectId,
    uint256 poolId,
    NftDeposit[] memory cards
  ) private returns (uint256) {
    INFTVillageCards poolCards = poolcards[projectId];

    uint256 harvestRelief;
    NftDeposit[] storage harvestCards = userNftInfo[projectId][poolId][user].harvest;
    if (harvestCards.length == 0) return 0;
    uint256 i = harvestCards.length - 1;
    while (true) {
      require(cards[i].tokenId == harvestCards[i].tokenId, "CardHandler: Invalid Card Id");
      require(
        harvestCards[i].amount >= cards[i].amount,
        "CardHandler: Card amount should not be greater than deposited amount!"
      );
      if (cards[i].amount > 0) {
        harvestRelief += poolCards.getHarvestRelief(cards[i].tokenId) * cards[i].amount;
        poolCards.safeTransferFrom(address(this), user, cards[i].tokenId, cards[i].amount, "");
        harvestCards[i].amount -= cards[i].amount;
        if (harvestCards[i].amount == 0) {
          // all cards are withdrawn, so we can delete the record
          harvestCards[i] = harvestCards[harvestCards.length - 1];
          harvestCards.pop();
        }
      }
      if (i == 0) break;
      i--;
    }
    return harvestRelief;
  }

  function withdrawMultiplierCard(
    address user,
    uint256 projectId,
    uint256 poolId,
    NftDeposit[] memory cards
  ) private returns (uint256) {
    INFTVillageCards poolCards = poolcards[projectId];

    NftDeposit[] storage multiplierCards = userNftInfo[projectId][poolId][user].multiplier;
    if (multiplierCards.length == 0) return 0;
    uint256 multiplier;
    uint256 i = multiplierCards.length - 1;
    while (true) {
      require(cards[i].tokenId == multiplierCards[i].tokenId, "CardHandler: Invalid Card Id");
      require(
        multiplierCards[i].amount >= cards[i].amount,
        "CardHandler: Card amount should not be greater than deposited amount!"
      );
      if (cards[i].amount > 0) {
        multiplier += poolCards.getMultiplier(cards[i].tokenId) * cards[i].amount;
        poolCards.safeTransferFrom(address(this), user, cards[i].tokenId, cards[i].amount, "");
        multiplierCards[i].amount -= cards[i].amount;
        if (multiplierCards[i].amount == 0) {
          // all cards are withdrawn, so we can delete the record
          multiplierCards[i] = multiplierCards[multiplierCards.length - 1];
          multiplierCards.pop();
        }
      }
      if (i == 0) break;
      i--;
    }
    return multiplier;
  }

  function onERC1155Received(
    address,
    address,
    uint256,
    uint256,
    bytes calldata
  ) public view override returns (bytes4) {
    require(_inDeposit, "CardHandler: Invalid ERC1155 Deposit!");
    return this.onERC1155Received.selector;
  }

  function onERC1155BatchReceived(
    address,
    address,
    uint256[] calldata,
    uint256[] calldata,
    bytes calldata
  ) public view override returns (bytes4) {
    require(_inDeposit, "CardHandler: Invalid ERC1155 Deposit!");
    return this.onERC1155BatchReceived.selector;
  }

  function onERC721Received(
    address,
    address,
    uint256,
    bytes memory
  ) public view override returns (bytes4) {
    require(_inDeposit, "CardHandler: Invalid ERC721 Deposit!");
    return this.onERC721Received.selector;
  }

  function drainAccidentallySentTokens(
    IERC20 token,
    address recipient,
    uint256 amount
  ) external onlyOwner {
    token.transfer(recipient, amount);
  }
}
