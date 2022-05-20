// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "../interfaces/IERC20Mintable.sol";
import "../interfaces/ICardHandler.sol";
import "../interfaces/IProjectHandler.sol";
import "../interfaces/IReferral.sol";
import "../interfaces/IFeeReceiver.sol";
import "../general/BaseStructs.sol";

contract Reserve is Ownable {
  function safeTransfer(
    IERC20 rewardToken,
    address _to,
    uint256 _amount
  ) external onlyOwner {
    uint256 tokenBal = rewardToken.balanceOf(address(this));
    if (_amount > tokenBal) {
      rewardToken.transfer(_to, tokenBal);
    } else {
      rewardToken.transfer(_to, _amount);
    }
  }
}

/**
    The NFTVillageChief provides following NFT cards to provide utility features to users.
    
    - Required Cards
        These nft cards are required to use a pool, without these cards you cannot enter a pool.
    - Multiplier Card
        This card increases the user shares of the reward pool, multiple cards can be used together to increase shares further.
    - Harvest Card
        This card is used to provide harvesting relief, so user can harvest more frequently, by using higher value or multiple harvest cards together.
    - Fee Discount Card
        This card provides discount on deposit/withdraw fees, multiple cards can be aggregated to get higher discounts.
 */

contract NFTVillageChief is BaseStructs, Ownable, ERC721Holder, ERC1155Holder {
  using Math for uint256;
  using SafeMath for uint256;
  using SafeMath for uint16;
  using SafeERC20 for IERC20;

  ICardHandler public cardHandler;
  IProjectHandler public projectHandler;

  mapping(uint256 => mapping(uint256 => mapping(address => UserInfo))) public userInfo;
  mapping(uint256 => mapping(uint256 => mapping(address => UserRewardInfo[]))) public userRewardInfo;

  IReferral public referral;

  uint256 public constant CARD_AMOUNT_MULTIPLIER = 1e18;
  uint256 public constant FEE_DENOMINATOR = 10000;
  uint256 public constant REWARD_MULTIPLICATOR = 1e12;
  uint256 public constant BASE_SHARE_MULTIPLIER = 10000;

  Reserve public rewardReserve;

  event Deposit(address indexed user, uint256 indexed projectId, uint256 indexed poolId, uint256 amount);
  event Withdraw(address indexed user, uint256 indexed projectId, uint256 indexed poolId, uint256 amount);

  event EmergencyWithdraw(address indexed user, uint256 indexed projectId, uint256 indexed poolId, uint256 amount);
  event RewardLockedUp(address indexed user, uint256 indexed projectId, uint256 indexed poolId, uint256 amountLockedUp);
  event ReferralCommissionPaid(address indexed user, address indexed referrer, uint256 commissionAmount);

  event ReferralUpdated(address indexed oldReferral, address indexed newReferral);

  modifier validatePoolByPoolId(uint256 projectId, uint256 poolId) {
    require(poolId < projectHandler.getProjectInfo(projectId).pools.length, "NFTVillageChief: Pool does not exist");
    _;
  }

  // using custom modifier cause the openzeppelin ReentrancyGuard exceeds the contract size limit
  bool entered;
  modifier nonReentrant() {
    require(!entered);
    entered = true;
    _;
    entered = false;
  }

  bool _inDeposit;
  modifier inDeposit() {
    _inDeposit = true;
    _;
    _inDeposit = false;
  }

  constructor() {
    rewardReserve = new Reserve();
  }

  function setProjectAndCardHandler(IProjectHandler _projectHandler, ICardHandler _cardHandler) external onlyOwner {
    require(address(projectHandler) == address(0) && address(cardHandler) == address(0));
    require(address(_projectHandler) != address(0) && address(_cardHandler) != address(0));
    projectHandler = _projectHandler;
    cardHandler = _cardHandler;

    projectHandler.setCardHandler(_cardHandler);
    cardHandler.setProjectHandler(address(_projectHandler));
  }

  function depositRewardToken(
    uint256 projectId,
    uint256 poolId,
    uint256 rewardId,
    uint256 amount
  ) external nonReentrant {
    require(
      msg.sender == projectHandler.getProjectInfo(projectId).admin ||
        msg.sender == projectHandler.getProjectInfo(projectId).feeRecipient,
      "NFTVillageChief: Only project admin!"
    );
    RewardInfo memory _rewardInfo = projectHandler.getRewardInfo(projectId, poolId)[rewardId];
    require(!_rewardInfo.mintable, "NFTVillageChief: Mintable!");

    uint256 initialBalance = _rewardInfo.token.balanceOf(address(rewardReserve));
    _rewardInfo.token.transferFrom(msg.sender, address(rewardReserve), amount);
    uint256 finalBalance = _rewardInfo.token.balanceOf(address(rewardReserve));
    projectHandler.setRewardSupply(projectId, poolId, rewardId, _rewardInfo.supply + finalBalance - initialBalance);
  }

  function _updatePool(uint256 projectId, uint256 poolId) private {
    ProjectInfo memory project = projectHandler.getProjectInfo(projectId);
    PoolInfo memory _pool = project.pools[poolId];
    RewardInfo[] memory rewardInfo = projectHandler.getRewardInfo(projectId, poolId);
    for (uint256 i = 0; i < rewardInfo.length; i++) {
      RewardInfo memory _rewardInfo = rewardInfo[i];

      if (_rewardInfo.paused) {
        projectHandler.setLastRewardBlock(projectId, poolId, i, block.number);
        continue;
      }

      if (block.number <= _rewardInfo.lastRewardBlock) continue;

      if (_pool.totalShares == 0 || _rewardInfo.rewardPerBlock == 0) {
        projectHandler.setLastRewardBlock(projectId, poolId, i, block.number);
        continue;
      }

      uint256 rewardAmount = block.number.sub(_rewardInfo.lastRewardBlock).mul(_rewardInfo.rewardPerBlock);
      uint256 devFee = rewardAmount.mul(project.rewardFee).div(FEE_DENOMINATOR);
      uint256 adminFee = rewardAmount.mul(project.adminReward).div(FEE_DENOMINATOR);
      uint256 totalRewards = rewardAmount.add(devFee).add(adminFee);
      IFeeReceiver rewardFeeRecipient = projectHandler.rewardFeeRecipient();
      if (!_rewardInfo.mintable && _rewardInfo.supply < totalRewards) {
        totalRewards = _rewardInfo.supply;
        rewardAmount = (FEE_DENOMINATOR * totalRewards) / (FEE_DENOMINATOR + project.adminReward + project.rewardFee);
        devFee = rewardAmount.mul(project.rewardFee).div(FEE_DENOMINATOR);
        adminFee = rewardAmount.mul(project.adminReward).div(FEE_DENOMINATOR);
        rewardAmount = totalRewards - devFee - adminFee;
      }
      if (_rewardInfo.mintable) {
        projectHandler.setRewardPerShare(
          projectId,
          poolId,
          i,
          _rewardInfo.accRewardPerShare.add(rewardAmount.mul(REWARD_MULTIPLICATOR).div(_pool.totalShares))
        );
        if (devFee > 0) {
          _rewardInfo.token.mint(address(rewardFeeRecipient), devFee);
          rewardFeeRecipient.onFeeReceived(address(_rewardInfo.token), devFee);
        }
        if (adminFee > 0) {
          _rewardInfo.token.mint(project.feeRecipient, adminFee);
        }
        _rewardInfo.token.mint(address(rewardReserve), rewardAmount);
      } else {
        if (rewardAmount > 0)
          projectHandler.setRewardPerShare(
            projectId,
            poolId,
            i,
            _rewardInfo.accRewardPerShare.add(rewardAmount.mul(REWARD_MULTIPLICATOR).div(_pool.totalShares))
          );
        if (devFee > 0) {
          rewardReserve.safeTransfer(_rewardInfo.token, address(rewardFeeRecipient), devFee);
          rewardFeeRecipient.onFeeReceived(address(_rewardInfo.token), devFee);
        }
        if (adminFee > 0) rewardReserve.safeTransfer(_rewardInfo.token, project.feeRecipient, adminFee);
        projectHandler.setRewardSupply(projectId, poolId, i, _rewardInfo.supply - totalRewards);
      }
      projectHandler.setLastRewardBlock(projectId, poolId, i, block.number);
    }
  }

  function pendingRewards(
    uint256 projectId,
    uint256 poolId,
    address _user
  ) external view returns (uint256[] memory) {
    UserInfo memory user = userInfo[projectId][poolId][_user];
    UserRewardInfo[] memory userReward = userRewardInfo[projectId][poolId][_user];
    return projectHandler.pendingRewards(projectId, poolId, user, userReward);
  }

  function _updateRewardDebt(uint256 projectId, uint256 poolId) private {
    UserInfo storage user = userInfo[projectId][poolId][msg.sender];
    UserRewardInfo[] storage userReward = userRewardInfo[projectId][poolId][msg.sender];
    RewardInfo[] memory _rewardInfo = projectHandler.getRewardInfo(projectId, poolId);
    while (userReward.length < _rewardInfo.length) userReward.push();
    for (uint256 i = 0; i < userReward.length; i++) {
      userReward[i].rewardDebt = user.shares.mul(_rewardInfo[i].accRewardPerShare).div(REWARD_MULTIPLICATOR);
    }
  }

  function _updateShares(uint256 projectId, uint256 poolId) internal {
    UserInfo storage user = userInfo[projectId][poolId][msg.sender];
    uint256 totalShares = projectHandler.getProjectInfo(projectId).pools[poolId].totalShares;

    uint256 previousShares = user.shares;
    uint256 multiplier = user.shareMultiplier + BASE_SHARE_MULTIPLIER;
    user.shares = user.amount.mul(multiplier).div(BASE_SHARE_MULTIPLIER);
    projectHandler.setPoolShares(projectId, poolId, totalShares + user.shares - previousShares);
  }

  function deposit(
    uint256 projectId,
    uint256 poolId,
    uint256 amount,
    NftDeposit[] memory depositFeeCards,
    NftDeposit[] memory withdrawFeeCards,
    NftDeposit[] memory harvestCards,
    NftDeposit[] memory multiplierCards,
    NftDeposit[] memory requireCards,
    address referrer
  ) external validatePoolByPoolId(projectId, poolId) nonReentrant inDeposit {
    ProjectInfo memory project = projectHandler.getProjectInfo(projectId);
    PoolInfo memory pool = project.pools[poolId];
    UserInfo storage user = userInfo[projectId][poolId][msg.sender];

    require(!project.paused, "NFTVillageChief: Project paused!");
    require(!pool.lockDeposit, "NFTVillageChief: Deposit locked!");
    require(pool.minDeposit <= amount || amount == 0, "NFTVillageChief: Deposit amount too low!");

    _updatePool(projectId, poolId);
    _payOrLockupPendingToken(projectId, poolId);

    _depositFeeDiscountCards(projectId, poolId, amount, depositFeeCards, withdrawFeeCards);
    if (amount > 0) _depositTokens(projectId, poolId, amount);

    if (amount > 0 && address(referral) != address(0) && referrer != address(0) && referrer != msg.sender) {
      referral.recordReferral(msg.sender, referrer);
    }

    _depositCards(projectId, poolId, harvestCards, multiplierCards, requireCards);

    _updateShares(projectId, poolId);
    _updateRewardDebt(projectId, poolId);

    require(pool.maxDeposit >= user.amount || amount == 0, "NFTVillageChief: Deposit amount too high!");
    emit Deposit(msg.sender, projectId, poolId, amount);
  }

  function _depositFeeDiscountCards(
    uint256 projectId,
    uint256 poolId,
    uint256 amount,
    NftDeposit[] memory depositFeeCards,
    NftDeposit[] memory withdrawFeeCards
  ) private {
    UserInfo storage user = userInfo[projectId][poolId][msg.sender];
    // only allow to use withdraw fee discout card on first deposit
    if (user.amount == 0) {
      uint256 withdrawFeeDiscount = cardHandler.useCard(
        msg.sender,
        uint8(CardType.FEE_DISCOUNT),
        projectId,
        poolId,
        withdrawFeeCards
      );
      user.withdrawFeeDiscount = withdrawFeeDiscount > FEE_DENOMINATOR ? FEE_DENOMINATOR : withdrawFeeDiscount;
    }
    if (amount > 0) {
      uint256 depositFeeDiscount = cardHandler.useCard(
        msg.sender,
        uint8(CardType.FEE_DISCOUNT),
        projectId,
        poolId,
        depositFeeCards
      ) + user.depositFeeDiscount;
      user.depositFeeDiscount = depositFeeDiscount > FEE_DENOMINATOR ? FEE_DENOMINATOR : depositFeeDiscount;
    }
  }

  function _depositCards(
    uint256 projectId,
    uint256 poolId,
    NftDeposit[] memory harvestCards,
    NftDeposit[] memory multiplierCards,
    NftDeposit[] memory requiredCards
  ) private {
    require(poolId < projectHandler.getProjectInfo(projectId).pools.length, "NFTVillageChief: Pool does not exist");

    UserInfo storage user = userInfo[projectId][poolId][msg.sender];

    cardHandler.useCard(msg.sender, uint8(CardType.REQUIRED), projectId, poolId, requiredCards);
    uint256 harvestRelief = cardHandler.useCard(
      msg.sender,
      uint8(CardType.HARVEST_RELIEF),
      projectId,
      poolId,
      harvestCards
    );
    user.harvestRelief += harvestRelief;
    if (user.canHarvestAt > 0) user.canHarvestAt -= harvestRelief;

    user.shareMultiplier += cardHandler.useCard(
      msg.sender,
      uint8(CardType.MULTIPLIER),
      projectId,
      poolId,
      multiplierCards
    );
  }

  function _depositTokens(
    uint256 projectId,
    uint256 poolId,
    uint256 amount
  ) private {
    ProjectInfo memory project = projectHandler.getProjectInfo(projectId);
    PoolInfo memory pool = project.pools[poolId];
    UserInfo storage user = userInfo[projectId][poolId][msg.sender];

    user.stakedTimestamp = block.timestamp;
    uint256 depositedAmount = _transferStakedToken(pool, address(msg.sender), address(this), amount);
    uint256 adminDepositFee;
    if (user.depositFeeDiscount < FEE_DENOMINATOR && pool.stakedTokenStandard == uint8(TokenStandard.ERC20))
      adminDepositFee =
        (amount * pool.depositFee * (FEE_DENOMINATOR - user.depositFeeDiscount)) /
        FEE_DENOMINATOR /
        FEE_DENOMINATOR;
    if (adminDepositFee > 0) _transferStakedToken(pool, address(this), project.feeRecipient, adminDepositFee);
    user.amount += depositedAmount - adminDepositFee;
    projectHandler.setStakedAmount(projectId, poolId, pool.stakedAmount.add(depositedAmount).sub(adminDepositFee));
  }

  function _transferStakedToken(
    PoolInfo memory pool,
    address from,
    address to,
    uint256 amount
  ) private returns (uint256) {
    if (pool.stakedTokenStandard == uint8(TokenStandard.ERC20)) {
      uint256 initialBalance = IERC20(pool.stakedToken).balanceOf(to);
      if (from == address(this)) IERC20(pool.stakedToken).safeTransfer(to, amount);
      else IERC20(pool.stakedToken).safeTransferFrom(from, to, amount);
      uint256 finalBalance = IERC20(pool.stakedToken).balanceOf(to);
      return finalBalance.sub(initialBalance);
    } else if (pool.stakedTokenStandard == uint8(TokenStandard.ERC721)) {
      cardHandler.ERC721Transferfrom(pool.stakedToken, from, to, pool.stakedTokenId);
      return CARD_AMOUNT_MULTIPLIER;
    } else if (pool.stakedTokenStandard == uint8(TokenStandard.ERC1155)) {
      cardHandler.ERC1155Transferfrom(pool.stakedToken, from, to, pool.stakedTokenId, amount);
      return from == address(this) ? amount / CARD_AMOUNT_MULTIPLIER : amount * CARD_AMOUNT_MULTIPLIER;
    } else if (pool.stakedTokenStandard == uint8(TokenStandard.NONE)) {
      return CARD_AMOUNT_MULTIPLIER;
    }
    return 0;
  }

  function withdraw(
    uint256 projectId,
    uint256 poolId,
    uint256 amount
  ) external nonReentrant {
    require(poolId < projectHandler.getProjectInfo(projectId).pools.length, "NFTVillageChief: Pool does not exist");

    ProjectInfo memory project = projectHandler.getProjectInfo(projectId);
    PoolInfo memory pool = project.pools[poolId];
    UserInfo storage user = userInfo[projectId][poolId][msg.sender];
    uint256 amountToTransfer = pool.stakedTokenStandard == uint8(TokenStandard.ERC20)
      ? amount
      : amount * CARD_AMOUNT_MULTIPLIER;
    require(user.amount >= amountToTransfer, "NFTVillageChief: Invalid withdraw!");
    _updatePool(projectId, poolId);
    _payOrLockupPendingToken(projectId, poolId);
    uint256 withdrawFeeDiscount = user.withdrawFeeDiscount;
    // withdraw all cards, if user want's to withdraw full amount
    if (user.amount == amountToTransfer) {
      cardHandler.withdrawCard(
        msg.sender,
        uint8(CardType.REQUIRED),
        projectId,
        poolId,
        cardHandler.getUserCardsInfo(projectId, poolId, msg.sender).required
      );
      cardHandler.withdrawCard(
        msg.sender,
        uint8(CardType.FEE_DISCOUNT),
        projectId,
        poolId,
        cardHandler.getUserCardsInfo(projectId, poolId, msg.sender).feeDiscount
      );
      user.harvestRelief -= cardHandler.withdrawCard(
        msg.sender,
        uint8(CardType.HARVEST_RELIEF),
        projectId,
        poolId,
        cardHandler.getUserCardsInfo(projectId, poolId, msg.sender).harvest
      );
      user.shareMultiplier -= cardHandler.withdrawCard(
        msg.sender,
        uint8(CardType.MULTIPLIER),
        projectId,
        poolId,
        cardHandler.getUserCardsInfo(projectId, poolId, msg.sender).multiplier
      );
      user.depositFeeDiscount = 0;
      user.withdrawFeeDiscount = 0;
    }
    if (amount > 0) {
      projectHandler.setStakedAmount(projectId, poolId, pool.stakedAmount.sub(amountToTransfer));
      user.amount = user.amount.sub(amountToTransfer);

      // calculate withdrawl fee, only collect fee is token standard is ERC20
      if (pool.maxWithdrawlFee != 0 && pool.stakedTokenStandard == uint8(TokenStandard.ERC20)) {
        uint256 withdrawFee = pool.minWithdrawlFee;
        uint256 stakedTime = block.timestamp - user.stakedTimestamp;
        if (pool.minWithdrawlFee < pool.maxWithdrawlFee && pool.withdrawlFeeReliefInterval > stakedTime) {
          uint256 feeReliefOverTime = (((stakedTime * 1e8) / pool.withdrawlFeeReliefInterval) *
            (pool.maxWithdrawlFee - pool.minWithdrawlFee)) / 1e8;
          withdrawFee = pool.maxWithdrawlFee - feeReliefOverTime;
          if (withdrawFee < pool.minWithdrawlFee) withdrawFee = pool.minWithdrawlFee;
        }
        uint256 feeAmount = (amountToTransfer * withdrawFee) / FEE_DENOMINATOR; // withdraw fee
        feeAmount = feeAmount - ((feeAmount * withdrawFeeDiscount) / FEE_DENOMINATOR); // withdraw fee after discount
        if (feeAmount > 0) {
          _transferStakedToken(pool, address(this), project.feeRecipient, feeAmount);
          amountToTransfer = amountToTransfer - feeAmount;
        }
      }
      _transferStakedToken(
        pool,
        address(this),
        address(msg.sender),
        pool.stakedTokenStandard == uint8(TokenStandard.ERC20) ? amountToTransfer : amount
      );
    }
    _updateShares(projectId, poolId);
    _updateRewardDebt(projectId, poolId);
    emit Withdraw(msg.sender, projectId, poolId, amount);
  }

  function withdrawHarvestCard(
    uint256 projectId,
    uint256 poolId,
    NftDeposit[] calldata cards
  ) external nonReentrant {
    UserInfo storage user = userInfo[projectId][poolId][msg.sender];
    uint256 withdrawnRelief = cardHandler.withdrawCard(
      msg.sender,
      uint8(CardType.HARVEST_RELIEF),
      projectId,
      poolId,
      cards
    );
    user.harvestRelief -= withdrawnRelief;
    user.canHarvestAt += withdrawnRelief;
  }

  function withdrawMultiplierCard(
    uint256 projectId,
    uint256 poolId,
    NftDeposit[] calldata cards
  ) external nonReentrant validatePoolByPoolId(projectId, poolId) {
    _updatePool(projectId, poolId);
    _payOrLockupPendingToken(projectId, poolId);
    UserInfo storage user = userInfo[projectId][poolId][msg.sender];
    user.shareMultiplier -= cardHandler.withdrawCard(msg.sender, uint8(CardType.MULTIPLIER), projectId, poolId, cards);
    _updateShares(projectId, poolId);
    _updateRewardDebt(projectId, poolId);
  }

  function _payOrLockupPendingToken(uint256 projectId, uint256 poolId) private {
    ProjectInfo memory project = projectHandler.getProjectInfo(projectId);
    PoolInfo memory pool = project.pools[poolId];
    UserInfo storage user = userInfo[projectId][poolId][msg.sender];
    UserRewardInfo[] storage userReward = userRewardInfo[projectId][poolId][msg.sender];
    RewardInfo[] memory _rewardInfo = projectHandler.getRewardInfo(projectId, poolId);

    if (user.canHarvestAt == 0) {
      user.canHarvestAt = block.timestamp.add(
        user.harvestRelief > pool.harvestInterval ? 0 : pool.harvestInterval - user.harvestRelief
      );
    }

    bool _canHarvest = canHarvest(projectId, poolId, msg.sender);
    for (uint256 i = 0; i < _rewardInfo.length; i++) {
      if (userReward.length == 0 || userReward.length - 1 < i) userReward.push();
      uint256 pending = user.shares.mul(_rewardInfo[i].accRewardPerShare).div(REWARD_MULTIPLICATOR).sub(
        userReward[i].rewardDebt
      );
      if (_canHarvest) {
        if (pending > 0 || userReward[i].rewardLockedUp > 0) {
          uint256 totalRewards = pending.add(userReward[i].rewardLockedUp);

          // reset lockup
          userReward[i].rewardLockedUp = 0;

          // send rewards
          rewardReserve.safeTransfer(_rewardInfo[i].token, msg.sender, totalRewards);
          _payReferralCommission(projectId, poolId, i, msg.sender, totalRewards, project.referralFee, _rewardInfo[i]);
        }
      } else if (pending > 0) {
        userReward[i].rewardLockedUp = userReward[i].rewardLockedUp.add(pending);
        emit RewardLockedUp(msg.sender, projectId, poolId, pending);
      }
    }
    if (_canHarvest)
      user.canHarvestAt = block.timestamp.add(
        user.harvestRelief > pool.harvestInterval ? 0 : pool.harvestInterval - user.harvestRelief
      );
  }

  function _payReferralCommission(
    uint256 projectId,
    uint256 poolId,
    uint256 rewardInfoIndex,
    address _user,
    uint256 _pending,
    uint256 _referralCommissionRate,
    RewardInfo memory rewardInfo
  ) internal {
    if (address(referral) != address(0) && _referralCommissionRate > 0) {
      address referrer = referral.getReferrer(_user);
      uint256 commissionAmount = _pending.mul(_referralCommissionRate).div(FEE_DENOMINATOR);

      if (referrer != address(0) && commissionAmount > 0) {
        if (rewardInfo.mintable) {
          rewardInfo.token.mint(referrer, commissionAmount);
          referral.recordReferralCommission(referrer, commissionAmount);
          emit ReferralCommissionPaid(_user, referrer, commissionAmount);
        } else if (commissionAmount <= rewardInfo.supply) {
          projectHandler.setRewardSupply(projectId, poolId, rewardInfoIndex, rewardInfo.supply - commissionAmount);
          rewardReserve.safeTransfer(rewardInfo.token, referrer, commissionAmount);
          referral.recordReferralCommission(referrer, commissionAmount);
          emit ReferralCommissionPaid(_user, referrer, commissionAmount);
        }
      }
    }
  }

  function setReferral(IReferral _referral) external onlyOwner {
    require(address(_referral) != address(0));
    emit ReferralUpdated(address(referral), address(_referral));
    referral = _referral;
  }

  function canHarvest(
    uint256 _projectId,
    uint256 _poolId,
    address _user
  ) public view returns (bool) {
    UserInfo storage user = userInfo[_projectId][_poolId][_user];
    return block.timestamp >= user.canHarvestAt;
  }

  function emergencyWithdraw(uint256 projectId, uint256 poolId)
    external
    validatePoolByPoolId(projectId, poolId)
    nonReentrant
  {
    ProjectInfo memory project = projectHandler.getProjectInfo(projectId);
    PoolInfo memory pool = project.pools[poolId];
    UserInfo storage user = userInfo[projectId][poolId][msg.sender];

    cardHandler.withdrawCard(
      msg.sender,
      uint8(CardType.REQUIRED),
      projectId,
      poolId,
      cardHandler.getUserCardsInfo(projectId, poolId, msg.sender).required
    );
    cardHandler.withdrawCard(
      msg.sender,
      uint8(CardType.FEE_DISCOUNT),
      projectId,
      poolId,
      cardHandler.getUserCardsInfo(projectId, poolId, msg.sender).feeDiscount
    );
    cardHandler.withdrawCard(
      msg.sender,
      uint8(CardType.HARVEST_RELIEF),
      projectId,
      poolId,
      cardHandler.getUserCardsInfo(projectId, poolId, msg.sender).harvest
    );
    cardHandler.withdrawCard(
      msg.sender,
      uint8(CardType.MULTIPLIER),
      projectId,
      poolId,
      cardHandler.getUserCardsInfo(projectId, poolId, msg.sender).multiplier
    );

    emit EmergencyWithdraw(msg.sender, projectId, poolId, user.amount);

    _transferStakedToken(
      pool,
      address(this),
      address(msg.sender),
      pool.stakedTokenStandard == uint8(TokenStandard.ERC20) ? user.amount : user.amount / CARD_AMOUNT_MULTIPLIER
    );
    projectHandler.setStakedAmount(projectId, poolId, pool.stakedAmount - Math.min(user.amount, pool.stakedAmount));
    projectHandler.setPoolShares(projectId, poolId, pool.totalShares - Math.min(user.shares, pool.totalShares));
    delete userInfo[projectId][poolId][msg.sender];
    delete userRewardInfo[projectId][poolId][msg.sender];
  }

  function emergencyProjectAdminWithdraw(
    uint256 projectId,
    uint256 poolId,
    uint256 rewardId
  ) external nonReentrant {
    ProjectInfo memory project = projectHandler.getProjectInfo(projectId);
    require(msg.sender == project.admin);

    RewardInfo memory _rewardInfo = projectHandler.getRewardInfo(projectId, poolId)[rewardId];
    _rewardInfo.token.transfer(project.admin, _rewardInfo.token.balanceOf(address(this)));
    rewardReserve.safeTransfer(_rewardInfo.token, project.admin, _rewardInfo.supply);
    projectHandler.setRewardSupply(projectId, poolId, rewardId, 0);
    projectHandler.setLastRewardBlock(projectId, poolId, rewardId, block.number);
  }

  function onERC1155Received(
    address,
    address,
    uint256,
    uint256,
    bytes calldata
  ) public view override returns (bytes4) {
    require(_inDeposit);
    return this.onERC1155Received.selector;
  }

  function onERC1155BatchReceived(
    address,
    address,
    uint256[] calldata,
    uint256[] calldata,
    bytes calldata
  ) public view override returns (bytes4) {
    require(_inDeposit);
    return this.onERC1155BatchReceived.selector;
  }

  function onERC721Received(
    address,
    address,
    uint256,
    bytes memory
  ) public view override returns (bytes4) {
    require(_inDeposit);
    return this.onERC721Received.selector;
  }
}
