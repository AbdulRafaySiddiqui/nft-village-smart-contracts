const { utils, constants } = require("ethers");

const TokenStandard = {
  ERC20: 0,
  ERC721: 1,
  ERC1155: 2,
  NONE: 3,
};

const DEFAULT_POOL = {
  stakedToken: constants.AddressZero,
  lockDeposit: false,
  stakedAmount: 0,
  totalShares: 0,
  depositFee: 0,
  minWithdrawlFee: 0,
  maxWithdrawlFee: 0,
  withdrawlFeeReliefInterval: 0,
  minDeposit: 0,
  maxDeposit: 0,
  harvestInterval: 0,
  stakedTokenStandard: TokenStandard.ERC20,
  stakedTokenId: 0,
  minRequiredCards: 0,
};

const DEFAULT_REWARD_INFO = {
  paused: false,
  mintable: false,
  lastRewardBlock: 0,
  accRewardPerShare: 0,
  supply: 0,
  token: constants.AddressZero,
  rewardPerBlock: 0,
};

const POOLS_INFO = [
  {
    ...DEFAULT_POOL,
    rewardInfo: [DEFAULT_REWARD_INFO],
  },
];

const NFTs = {};

const PROJECT_ADMIN = "0x2c67F197b7403d655a1E96CD9cfcb81151AAAEdb";

module.exports = {
  TokenStandard,
  DEFAULT_POOL,
  DEFAULT_REWARD_INFO,
  PROJECT_ADMIN,
  POOLS_INFO,
  NFTs,
};
