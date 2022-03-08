// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/INFTVillageCardFeatures.sol";

pragma solidity ^0.8.0;

contract NFTVillageCardFeatures is Ownable, INFTVillageCardFeatures {
  uint256[] public multiplierCards;
  uint256[] public feeDiscountCards;
  uint256[] public harvestReliefCards;

  mapping(uint256 => uint256) public multipliers;
  mapping(uint256 => uint256) public feeDiscounts;
  mapping(uint256 => uint256) public harvestReliefs;

  event HarvestReliefCardAdded(uint256 tokenId, uint256 _harvestRelief);
  event FeeDiscountCardAdded(uint256 tokenId, uint256 _feeDiscount);
  event MutliplierCardAdded(uint256 tokenId, uint256 _multiplier);

  event HarvestReliefCardRemoved(uint256 tokenId);
  event FeeDiscountCardRemoved(uint256 tokenId);
  event MutliplierCardRemoved(uint256 tokenId);

  function addHarvestReliefCard(uint256 _tokenId, uint256 _harvestRelief) external override {
    require(_harvestRelief != 0, "POOLCARDS: Invalid _harvestRelief!");
    harvestReliefCards.push(_tokenId);
    harvestReliefs[_tokenId] = _harvestRelief;
    emit HarvestReliefCardAdded(_tokenId, _harvestRelief);
  }

  function addFeeDiscountCard(uint256 _tokenId, uint256 _feeDiscount) external override onlyOwner {
    require(_feeDiscount != 0, "POOLCARDS: Invalid _feeDiscount!");
    feeDiscountCards.push(_tokenId);
    feeDiscounts[_tokenId] = _feeDiscount;
    emit FeeDiscountCardAdded(_tokenId, _feeDiscount);
  }

  function addMultiplierCard(uint256 _tokenId, uint256 _multiplier) external override onlyOwner {
    require(_multiplier != 0, "POOLCARDS: Invalid _multiplier!");
    multiplierCards.push(_tokenId);
    multipliers[_tokenId] = _multiplier;
    emit MutliplierCardAdded(_tokenId, _multiplier);
  }

  function removeHarvestReliefCard(uint256 index) external override onlyOwner {
    uint256 _tokenId = harvestReliefCards[index];
    harvestReliefCards[index] = harvestReliefCards[harvestReliefCards.length - 1];
    harvestReliefCards.pop();
    delete harvestReliefs[_tokenId];
    emit HarvestReliefCardRemoved(_tokenId);
  }

  function removeFeeDiscountCard(uint256 index) external override onlyOwner {
    uint256 _tokenId = feeDiscountCards[index];
    feeDiscountCards[index] = feeDiscountCards[feeDiscountCards.length - 1];
    feeDiscountCards.pop();
    delete feeDiscounts[_tokenId];
    emit FeeDiscountCardRemoved(_tokenId);
  }

  function removeMultiplierCard(uint256 index) external override onlyOwner {
    uint256 _tokenId = multiplierCards[index];
    multiplierCards[index] = multiplierCards[multiplierCards.length - 1];
    multiplierCards.pop();
    delete multipliers[_tokenId];
    emit MutliplierCardRemoved(_tokenId);
  }

  function getHarvestReliefCards() external view override returns (uint256[] memory) {
    return harvestReliefCards;
  }

  function getFeeDiscountCards() external view override returns (uint256[] memory) {
    return feeDiscountCards;
  }

  function getMultiplierCards() external view override returns (uint256[] memory) {
    return multiplierCards;
  }

  function getHarvestRelief(uint256 id) external view override returns (uint256) {
    uint256 harvestRelief = harvestReliefs[id];
    require(harvestRelief != 0, "POOLCARDS: Invalid Harvest Relief Card Id!");
    return harvestRelief;
  }

  function getFeeDiscount(uint256 id) external view override returns (uint256) {
    uint256 feeDiscount = feeDiscounts[id];
    require(feeDiscount != 0, "POOLCARDS: Invalid Fee Discount Card Id!");
    return feeDiscount;
  }

  function getMultiplier(uint256 id) external view override returns (uint256) {
    uint256 multiplier = multipliers[id];
    require(multiplier != 0, "POOLCARDS: Invalid Multiplier Card Id!");
    return multiplier;
  }
}
