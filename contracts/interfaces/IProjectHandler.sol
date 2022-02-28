// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./ICardHandler.sol";
import "./IFeeReceiver.sol";
import "../general/BaseStructs.sol";

interface IProjectHandler is BaseStructs {
  function setCardHandler(ICardHandler _cardHandler) external;

  function initializeProject(uint256 projectId) external;

  function getRewardInfo(uint256 projectId, uint256 poolId) external returns (RewardInfo[] calldata);

  function projectFeeRecipient() external returns (IFeeReceiver);

  function poolFeeRecipient() external returns (IFeeReceiver);

  function rewardFeeRecipient() external returns (IFeeReceiver);

  function projectFee() external returns (uint256);

  function poolFee() external returns (uint256);

  function rewardFee() external returns (uint256);

  function getProjectInfo(uint256 projectId) external returns (ProjectInfo memory);

  function projectLength() external view returns (uint256);

  function projectPoolLength(uint256 projectId) external view returns (uint256);

  function getPoolInfo(uint256 projectId, uint256 poolId) external view returns (PoolInfo memory);

  function addProject(
    address _admin,
    uint256 _adminReward,
    uint256 _referralFee,
    uint256 _startBlock,
    INFTVillageCards _poolCards
  ) external payable;

  function setProject(
    uint256 projectId,
    address _admin,
    uint256 _adminReward,
    uint256 _referralFee,
    INFTVillageCards _poolCards
  ) external;

  function addPool(
    uint256 projectId,
    PoolInfo memory _pool,
    RewardInfo[] memory _rewardInfo,
    NftDeposit[] calldata _requiredCards
  ) external payable;

  function setPool(
    uint256 projectId,
    uint256 poolId,
    PoolInfo calldata _pool,
    RewardInfo[] memory _rewardInfo
  ) external;

  function setPoolShares(
    uint256 projectId,
    uint256 poolId,
    uint256 shares
  ) external;

  function setStakedAmount(
    uint256 projectId,
    uint256 poolId,
    uint256 amount
  ) external;

  function setRewardPerBlock(
    uint256 projectId,
    uint256 poolId,
    uint256 rewardId,
    uint256 rewardPerBlock
  ) external;

  function setLastRewardBlock(
    uint256 projectId,
    uint256 poolId,
    uint256 rewardId,
    uint256 lastRewardBlock
  ) external;

  function setRewardPerShare(
    uint256 projectId,
    uint256 poolId,
    uint256 rewardId,
    uint256 accRewardPerShare
  ) external;

  function setRewardSupply(
    uint256 projectId,
    uint256 poolId,
    uint256 rewardId,
    uint256 supply
  ) external;

  function pendingRewards(
    uint256 projectId,
    uint256 poolId,
    UserInfo memory user,
    UserRewardInfo[] calldata userReward
  ) external view returns (uint256[] calldata);
}
