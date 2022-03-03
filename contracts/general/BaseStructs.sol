// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interfaces/IERC20Mintable.sol";
import "../interfaces/INFTVillageCards.sol";

interface BaseStructs {
  enum CardType {
    REQUIRED,
    FEE_DISCOUNT,
    HARVEST_RELIEF,
    MULTIPLIER
  }

  enum TokenStandard {
    ERC20,
    ERC721,
    ERC1155
  }

  struct NftDeposit {
    uint256 tokenId;
    uint256 amount;
  }

  struct NftDepositInfo {
    NftDeposit[] required;
    NftDeposit[] feeDiscount;
    NftDeposit[] harvest;
    NftDeposit[] multiplier;
  }

  struct ProjectInfo {
    address admin;
    uint256 adminReward;
    uint256 referralFee;
    uint256 rewardFee;
    uint256 startBlock;
    bool initialized;
    bool paused;
    INFTVillageCards cards;
    PoolInfo[] pools;
  }

  struct PoolInfo {
    address stakedToken;
    bool lockDeposit;
    uint8 stakedTokenStandard;
    uint256 stakedTokenId;
    uint256 stakedAmount;
    uint256 totalShares;
    uint16 depositFee;
    uint16 minWithdrawlFee;
    uint16 maxWithdrawlFee;
    uint16 withdrawlFeeReliefInterval;
    uint256 minDeposit;
    uint256 harvestInterval;
    bool minRequiredCards;
  }

  struct RewardInfo {
    IERC20Mintable token;
    bool paused;
    bool mintable;
    uint256 rewardPerBlock;
    uint256 lastRewardBlock;
    uint256 accRewardPerShare;
    uint256 supply;
  }

  struct UserInfo {
    uint256 amount;
    uint256 shares;
    uint256 shareMultiplier;
    uint256 canHarvestAt;
    uint256 harvestRelief;
    uint256 withdrawFeeDiscount;
    uint256 depositFeeDiscount;
    uint256 stakedTimestamp;
  }

  struct UserRewardInfo {
    uint256 rewardDebt;
    uint256 rewardLockedUp;
  }
}
