// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NFTVillageLaunchpad is Ownable {
  using SafeERC20 for IERC20;

  address payable public feeReceiver;

  uint256 public tokenRate;
  uint256 public minContribution;
  uint256 public maxContribution;

  mapping(address => uint256) public userContribution;
  mapping(address => uint256) public userClaim;

  uint256 public totalDistributions;
  mapping(uint256 => uint256) public totalContributions;

  IERC20 public token;
  bool public claimEnabled;
  bool public contributionEnabled;

  uint256 public currentRound;
  uint256 public totalRounds;
  mapping(uint256 => uint256) public roundLimits;

  event Contributed(address indexed account, uint256 indexed amount);
  event Claimed(address indexed account, uint256 indexed amount);
  event ClaimEnabledUpdated(bool enabled);
  event ContributionEnabledUpdated(bool enabled);
  event MinContributionUpdated(uint256 amount);
  event MaxContributionUpdated(uint256 amount);
  event TokenRateUpdated(uint256 rate);
  event FeeReceiverUpdated(address account);
  event RoundMoved(uint256 round);
  event RoundAdded(uint256 roundNumber);

  constructor(
    IERC20 _token,
    address payable _feeReceiver,
    uint256 _minContribution,
    uint256 _maxContribution,
    uint256 _tokenRate
  ) {
    token = _token;
    feeReceiver = _feeReceiver;
    minContribution = _minContribution;
    maxContribution = _maxContribution;
    tokenRate = _tokenRate;
  }

  function contribute() external payable {
    require(contributionEnabled, "NFTVillageLaunchpad: Contribution is disabled");
    require(
      roundLimits[currentRound] >= totalContributions[currentRound] + msg.value,
      "NFTVillageLaunchpad: Hardcap for current round is filled"
    );

    userContribution[msg.sender] += msg.value;
    totalContributions[currentRound] += msg.value;

    require(userContribution[msg.sender] >= minContribution, "NFTVillageLaunchpad: Minimun Contribution not met");
    require(userContribution[msg.sender] <= maxContribution, "NFTVillageLaunchpad: Maximum Contribution exceeded");

    feeReceiver.transfer(msg.value);
    emit Contributed(msg.sender, msg.value);
  }

  function claim() external {
    require(claimEnabled, "NFTVillageLaunchpad: Claim disabled");
    uint256 _contributions = userContribution[msg.sender] - userClaim[msg.sender];
    require(_contributions > 0, "NFTVillageLaunchpad: Only contributors are allowed to claim");

    uint256 _tokenAmount = _contributions * tokenRate;
    token.transfer(msg.sender, _tokenAmount);
    totalDistributions += _tokenAmount;
    userClaim[msg.sender] += _contributions;

    emit Claimed(msg.sender, _tokenAmount);
  }

  function setContributionEnabled(bool _contributionEnabled) external onlyOwner {
    contributionEnabled = _contributionEnabled;
    emit ContributionEnabledUpdated(_contributionEnabled);
  }

  function setClaimEnabled(bool _claimEnabled) external onlyOwner {
    claimEnabled = _claimEnabled;
    emit ClaimEnabledUpdated(_claimEnabled);
  }

  function setMinContribution(uint256 amount) external onlyOwner {
    minContribution = amount;
    emit MinContributionUpdated(amount);
  }

  function setMaxContribution(uint256 amount) external onlyOwner {
    maxContribution = amount;
    emit MaxContributionUpdated(amount);
  }

  function setTokenRate(uint256 rate) external onlyOwner {
    tokenRate = rate;
    emit TokenRateUpdated(rate);
  }

  function setFeeReceiver(address payable account) external onlyOwner {
    feeReceiver = account;
    emit FeeReceiverUpdated(account);
  }

  function addRound(uint256 hardcap) external onlyOwner {
    totalRounds++;
    roundLimits[totalRounds] = hardcap;
    emit RoundAdded(totalRounds);
  }

  function moveToNextRound() external onlyOwner {
    require(totalRounds > currentRound, "NFTVillageLaunchpad: Rounds are finished");
    currentRound++;
    emit RoundMoved(currentRound);
  }

  function setCurrentRound(uint256 round) external onlyOwner {
    currentRound = round;
  }

  function setToken(IERC20 _token) external onlyOwner {
    token = _token;
  }

  function drainAccidentallySentTokens(
    IERC20 _token,
    address recipient,
    uint256 amount
  ) external onlyOwner {
    _token.transfer(recipient, amount);
  }

  function drainAccidentallySentEth(address recipient, uint256 amount) external onlyOwner {
    payable(recipient).transfer(amount);
  }
}
