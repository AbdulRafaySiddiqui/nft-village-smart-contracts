// SPDX-License-Identifier: MIT

import "./INFTVillageCards.sol";
import "../general/BaseStructs.sol";

pragma solidity ^0.8.0;

interface ICardHandler is BaseStructs {
  function setProjectHandler(address _projectHandler) external;

  function ERC721Transferfrom(
    address token,
    address from,
    address to,
    uint256 amount
  ) external;

  function ERC1155Transferfrom(
    address token,
    address from,
    address to,
    uint256 tokenId,
    uint256 amount
  ) external;

  function getUserCardsInfo(
    uint256 projectId,
    uint256 poolId,
    address account
  ) external view returns (NftDepositInfo memory);

  function getPoolRequiredCards(uint256 projectId, uint256 poolId) external view returns (NftDeposit[] memory);

  function setPoolCard(uint256 _projectId, INFTVillageCards _poolcard) external;

  function addPoolRequiredCards(
    uint256 _projectId,
    uint256 _poolId,
    NftDeposit[] calldata _requiredCards
  ) external;

  function useCard(
    address user,
    uint8 cardType,
    uint256 projectId,
    uint256 poolId,
    NftDeposit[] calldata cards
  ) external returns (uint256);

  function withdrawCard(
    address user,
    uint8 cardType,
    uint256 projectId,
    uint256 poolId,
    NftDeposit[] calldata cards
  ) external returns (uint256);
}
