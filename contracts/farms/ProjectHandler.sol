// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/ICardHandler.sol";
import "../interfaces/IProjectHandler.sol";
import "../interfaces/IFeeReceiver.sol";
import "../general/BaseStructs.sol";

contract ProjectHandler is BaseStructs, IProjectHandler, Ownable {
  using SafeMath for uint256;

  mapping(uint256 => mapping(uint256 => RewardInfo[])) public rewardInfo;

  address public nftVillageChief;

  IFeeReceiver public override projectFeeRecipient;
  IFeeReceiver public override poolFeeRecipient;
  IFeeReceiver public override rewardFeeRecipient;
  uint256 public override projectFee;
  uint256 public override poolFee;
  uint256 public override rewardFee;

  ProjectInfo[] public projectInfo;
  ICardHandler public cardHandler;

  uint256 public constant FEE_DENOMINATOR = 10000;

  modifier onlyNFTVillageChief() {
    require(nftVillageChief == msg.sender, "ProjectHandler: Only NFTVillageChief");
    _;
  }

  event CardHandlerUpdate(address indexed oldHandler, address indexed newHandler);
  event ProjectFeeAndRecipientUpdated(address indexed recipient, uint256 indexed fee);
  event PoolFeeAndRecipientUpdated(address indexed recipient, uint256 indexed fee);
  event RewardFeeAndRecipientUpdated(address indexed recipient, uint256 indexed fee);

  constructor(
    address _nftVillageChief,
    address _owner,
    uint256 _projectFee,
    uint256 _poolFee,
    uint256 _rewardFee,
    address _projectFeeReceiver,
    address _poolFeeReceiver,
    address _rewardFeeReceiver
  ) {
    require(
      _nftVillageChief != address(0) &&
        _projectFeeReceiver != address(0) &&
        _poolFeeReceiver != address(0) &&
        _rewardFeeReceiver != address(0) &&
        _owner != address(0),
      "ProjectHandler: zero address"
    );

    nftVillageChief = _nftVillageChief;
    projectFee = _projectFee;
    poolFee = _poolFee;
    rewardFee = _rewardFee;

    projectFeeRecipient = IFeeReceiver(_projectFeeReceiver);
    poolFeeRecipient = IFeeReceiver(_poolFeeReceiver);
    rewardFeeRecipient = IFeeReceiver(_rewardFeeReceiver);

    transferOwnership(_owner);
  }

  function setCardHandler(ICardHandler _cardHandler) external override onlyNFTVillageChief {
    require(address(_cardHandler) != address(0), "ProjectHandler: _cardHandler is zero address");
    emit CardHandlerUpdate(address(cardHandler), address(_cardHandler));
    cardHandler = _cardHandler;
  }

  function initializeProject(uint256 projectId) external override {
    ProjectInfo storage project = projectInfo[projectId];
    require(project.admin == msg.sender, "ProjectHandler: Only Project Admin!");
    require(!project.initialized, "ProjectHandler: Project already initialized!");
    project.initialized = true;
    project.paused = false;
    project.startBlock = block.number;
    uint256 length = project.pools.length;
    for (uint256 p = 0; p < length; ++p) {
      RewardInfo[] storage rewardTokens = rewardInfo[projectId][p];
      for (uint256 r = 0; r < rewardTokens.length; r++) {
        rewardTokens[r].lastRewardBlock = project.startBlock;
      }
    }
  }

  function addProject(
    address _admin,
    uint256 _adminReward,
    uint256 _referralFee,
    uint256 _startBlock,
    INFTVillageCards _poolCards
  ) external payable override onlyOwner {
    require(_admin != address(0), "ProjectHandler: Invalid Admin!");
    require(msg.value == projectFee, "ProjectHandler: Invalid Project Fee!");

    uint256 fee = address(this).balance;
    projectFeeRecipient.onFeeReceived{value: fee}(address(0), fee);

    projectInfo.push();
    ProjectInfo storage project = projectInfo[projectInfo.length - 1];
    project.paused = true;
    project.admin = _admin;
    project.adminReward = _adminReward;
    project.referralFee = _referralFee;
    project.startBlock = _startBlock == 0 ? block.number : _startBlock;
    cardHandler.setPoolCard(projectInfo.length - 1, _poolCards);
  }

  function setProject(
    uint256 projectId,
    address _admin,
    uint256 _adminReward,
    uint256 _referralFee,
    INFTVillageCards _poolCards
  ) external override {
    ProjectInfo storage project = projectInfo[projectId];
    require(msg.sender == project.admin, "ProjectHandler: Only Project Admin!");
    require(_admin != address(0), "ProjectHandler: Invalid Admin!");

    project.admin = _admin;
    project.adminReward = _adminReward;
    project.referralFee = _referralFee;
    cardHandler.setPoolCard(projectId, _poolCards);
  }

  function addPool(
    uint256 projectId,
    PoolInfo memory _pool,
    RewardInfo[] memory _rewardInfo,
    NftDeposit[] calldata _requiredCards
  ) external payable override {
    ProjectInfo storage project = projectInfo[projectId];
    require(msg.sender == project.admin, "ProjectHandler: Only Project Admin!");
    require(msg.value == poolFee, "ProjectHandler: Invalid Pool Fee!");

    uint256 fee = address(this).balance;
    poolFeeRecipient.onFeeReceived{value: fee}(address(0), fee);

    require(_pool.stakedToken != address(0), "ProjectHandler: stakedToken is a zero address");
    require(_pool.stakedTokenStandard < 3, "ProjectHandler: Invalid stakedTokenStandard");
    _pool.stakedAmount = 0;
    _pool.totalShares = 0;
    project.pools.push(_pool);
    for (uint256 i = 0; i < _rewardInfo.length; i++) {
      _rewardInfo[i].accRewardPerShare = 0;
      _rewardInfo[i].supply = 0;
      _rewardInfo[i].lastRewardBlock = block.number > project.startBlock ? block.number : project.startBlock;
      rewardInfo[projectId][project.pools.length - 1].push(_rewardInfo[i]);
    }
    cardHandler.addPoolRequiredCards(projectId, project.pools.length - 1, _requiredCards);
  }

  function setPool(
    uint256 projectId,
    uint256 poolId,
    PoolInfo calldata _pool,
    RewardInfo[] memory _rewardInfo
  ) external override {
    ProjectInfo storage project = projectInfo[projectId];
    PoolInfo storage pool = project.pools[poolId];
    require(msg.sender == project.admin, "ProjectHandler: Only Project Admin!");

    pool.lockDeposit = _pool.lockDeposit;
    pool.minDeposit = _pool.minDeposit;
    pool.depositFee = _pool.depositFee;
    pool.harvestInterval = _pool.harvestInterval;
    pool.minWithdrawlFee = _pool.minWithdrawlFee;
    pool.maxWithdrawlFee = _pool.maxWithdrawlFee;
    pool.withdrawlFeeReliefInterval = _pool.withdrawlFeeReliefInterval;
    pool.minRequiredCards = _pool.minRequiredCards;

    RewardInfo[] storage __rewardInfo = rewardInfo[projectId][poolId];
    for (uint256 i = 0; i < _rewardInfo.length; i++) {
      if (i < __rewardInfo.length) {
        require(_rewardInfo[i].token == __rewardInfo[i].token, "ProjectHandler: Invalid reward info!");
        __rewardInfo[i].paused = _rewardInfo[i].paused;
        __rewardInfo[i].mintable = _rewardInfo[i].mintable;
        __rewardInfo[i].rewardPerBlock = _rewardInfo[i].rewardPerBlock;
      } else {
        _rewardInfo[i].accRewardPerShare = 0;
        _rewardInfo[i].supply = 0;
        _rewardInfo[i].lastRewardBlock = block.number > project.startBlock ? block.number : project.startBlock;
        rewardInfo[projectId][poolId].push(_rewardInfo[i]);
      }
    }
  }

  function setPoolShares(
    uint256 projectId,
    uint256 poolId,
    uint256 shares
  ) external override onlyNFTVillageChief {
    projectInfo[projectId].pools[poolId].totalShares = shares;
  }

  function setStakedAmount(
    uint256 projectId,
    uint256 poolId,
    uint256 amount
  ) external override onlyNFTVillageChief {
    projectInfo[projectId].pools[poolId].stakedAmount = amount;
  }

  function setRewardPerBlock(
    uint256 projectId,
    uint256 poolId,
    uint256 rewardId,
    uint256 rewardPerBlock
  ) external override onlyNFTVillageChief {
    rewardInfo[projectId][poolId][rewardId].rewardPerBlock = rewardPerBlock;
  }

  function setLastRewardBlock(
    uint256 projectId,
    uint256 poolId,
    uint256 rewardId,
    uint256 lastRewardBlock
  ) external override onlyNFTVillageChief {
    rewardInfo[projectId][poolId][rewardId].lastRewardBlock = lastRewardBlock;
  }

  function setRewardPerShare(
    uint256 projectId,
    uint256 poolId,
    uint256 rewardId,
    uint256 accRewardPerShare
  ) external override onlyNFTVillageChief {
    rewardInfo[projectId][poolId][rewardId].accRewardPerShare = accRewardPerShare;
  }

  function setRewardSupply(
    uint256 projectId,
    uint256 poolId,
    uint256 rewardId,
    uint256 supply
  ) external override onlyNFTVillageChief {
    rewardInfo[projectId][poolId][rewardId].supply = supply;
  }

  function setProjectFeeAndRecipient(IFeeReceiver recipient, uint256 fee) external onlyOwner {
    require(address(recipient) != address(0), "ProjectHandler: recipient is zero address");
    projectFeeRecipient = recipient;
    projectFee = fee;
    emit ProjectFeeAndRecipientUpdated(address(recipient), fee);
  }

  function setPoolFeeAndRecipient(IFeeReceiver recipient, uint256 fee) external onlyOwner {
    require(address(recipient) != address(0), "ProjectHandler: recipient is zero address");
    poolFeeRecipient = recipient;
    poolFee = fee;
    emit PoolFeeAndRecipientUpdated(address(recipient), fee);
  }

  function setRewardFeeAndRecipient(IFeeReceiver recipient, uint256 fee) external onlyOwner {
    require(address(recipient) != address(0), "ProjectHandler: recipient is zero address");
    rewardFeeRecipient = recipient;
    rewardFee = fee;
    emit RewardFeeAndRecipientUpdated(address(recipient), fee);
  }

  function projectLength() external view override returns (uint256) {
    return projectInfo.length;
  }

  function projectPoolLength(uint256 projectId) external view override returns (uint256) {
    return projectInfo[projectId].pools.length;
  }

  function getProjectInfo(uint256 projectId) external view override returns (ProjectInfo memory) {
    return projectInfo[projectId];
  }

  function getPoolInfo(uint256 projectId, uint256 poolId) external view override returns (PoolInfo memory) {
    return projectInfo[projectId].pools[poolId];
  }

  function getRewardInfo(uint256 projectId, uint256 poolId) external view override returns (RewardInfo[] memory) {
    return rewardInfo[projectId][poolId];
  }

  function pendingRewards(
    uint256 projectId,
    uint256 poolId,
    UserInfo calldata user,
    UserRewardInfo[] calldata userReward
  ) external view override onlyNFTVillageChief returns (uint256[] memory) {
    ProjectInfo storage project = projectInfo[projectId];
    PoolInfo storage pool = project.pools[poolId];
    uint256[] memory rewards = new uint256[](rewardInfo[projectId][poolId].length);
    // if user is not a staker, just return emtpy array of rewards
    if (userReward.length == 0) return rewards;
    // if user reward list is not updated, the client must call the deposit method in spacemoon contract first before using this function
    require(userReward.length == rewards.length, "ProjectHandler: The user reward list is not updated!");
    for (uint256 i = 0; i < rewardInfo[projectId][poolId].length; i++) {
      RewardInfo storage _rewardInfo = rewardInfo[projectId][poolId][i];
      uint256 accRewardPerShare = _rewardInfo.accRewardPerShare;
      if (
        block.number > _rewardInfo.lastRewardBlock &&
        pool.totalShares != 0 &&
        (_rewardInfo.supply > 0 || _rewardInfo.mintable)
      ) {
        uint256 multiplier = block.number.sub(_rewardInfo.lastRewardBlock);
        uint256 rewardAmount = multiplier.mul(_rewardInfo.rewardPerBlock);
        uint256 devFee = rewardAmount.mul(project.rewardFee).div(FEE_DENOMINATOR);
        uint256 adminFee = rewardAmount.mul(project.adminReward).div(FEE_DENOMINATOR);
        uint256 totalRewards = rewardAmount.add(devFee).add(adminFee);
        if (!_rewardInfo.mintable && _rewardInfo.supply < totalRewards) {
          rewardAmount =
            (FEE_DENOMINATOR * _rewardInfo.supply) /
            (FEE_DENOMINATOR + project.adminReward + project.rewardFee);
          devFee = rewardAmount.mul(project.rewardFee).div(FEE_DENOMINATOR);
          adminFee = rewardAmount.mul(project.adminReward).div(FEE_DENOMINATOR);
          rewardAmount = _rewardInfo.supply - devFee - adminFee;
        }
        accRewardPerShare = accRewardPerShare.add(rewardAmount.mul(1e12).div(pool.totalShares));
      }
      rewards[i] = user.shares.mul(accRewardPerShare).div(1e12).sub(userReward[i].rewardDebt);
    }
    return rewards;
  }

  function drainAccidentallySentTokens(
    IERC20 token,
    address recipient,
    uint256 amount
  ) external onlyOwner {
    token.transfer(recipient, amount);
  }
}
