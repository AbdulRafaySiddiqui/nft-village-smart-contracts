// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

abstract contract INFTVillageCardFeatures {
  function addHarvestReliefCard(uint256 _tokenId, uint256 _harvestRelief) external virtual;

  function addFeeDiscountCard(uint256 _tokenId, uint256 _feeDiscount) external virtual;

  function addMultiplierCard(uint256 _tokenId, uint256 _multiplier) external virtual;

  function removeHarvestReliefCard(uint256 _tokenId) external virtual;

  function removeFeeDiscountCard(uint256 _tokenId) external virtual;

  function removeMultiplierCard(uint256 _tokenId) external virtual;

  function getHarvestReliefCards() external view virtual returns (uint256[] memory);

  function getFeeDiscountCards() external view virtual returns (uint256[] memory);

  function getMultiplierCards() external view virtual returns (uint256[] memory);

  function getHarvestRelief(uint256 id) external virtual returns (uint256);

  function getFeeDiscount(uint256 id) external virtual returns (uint256);

  function getMultiplier(uint256 id) external virtual returns (uint256);
}
