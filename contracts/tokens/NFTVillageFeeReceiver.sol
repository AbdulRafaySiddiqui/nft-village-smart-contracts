// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/INFTVillageFeeReceiver.sol";
import "../interfaces/IDEXRouter.sol";

contract NFTVillageFeeReceiver is Ownable, INFTVillageFeeReceiver {
  IERC20 public token;
  IDEXRouter public router;
  address public feeRecipient;

  bool public swapEnabled = true;
  uint256 public swapThreshold = 1 ether;

  event FeeRecipientUpdated(address indexed feeRecipient);
  event RouterUpdated(address indexed router);
  event SwapUpdated(bool indexed enabled);
  event SwapThresholdUpdated(uint256 indexed threshold);

  modifier onlyToken() {
    require(msg.sender == address(token), "NFTVillageFeeReceiver: Only Token!");
    _;
  }

  constructor(
    address _token,
    address _router,
    address _owner
  ) {
    require(
      _token != address(0) && _router != address(0) && _owner != address(0),
      "NFTVillageFeeReceiver: zero address"
    );

    token = IERC20(_token);
    router = IDEXRouter(_router);
    transferOwnership(_owner);
  }

  function onFeeReceived(address sourceContract, uint256 amount) external override onlyToken {
    if (sourceContract != address(0)) {
      address recipient = swapEnabled ? address(this) : feeRecipient;
      token.transferFrom(address(token), recipient, amount);
      _swapTokensForETH();
    }
  }

  function _swapTokensForETH() private {
    uint256 amount = token.balanceOf(address(this));
    if (amount > swapThreshold) {
      address[] memory path = new address[](2);
      path[0] = address(token);
      path[1] = router.WETH();

      token.approve(address(router), amount);

      router.swapExactTokensForETHSupportingFeeOnTransferTokens(amount, 0, path, feeRecipient, block.timestamp);
    }
  }

  function setFeeRecipient(address _feeRecipient) external onlyOwner {
    require(_feeRecipient != address(0), "NFTVillageFeeReceiver: _feeRecipient is a zero address");
    feeRecipient = _feeRecipient;
    emit FeeRecipientUpdated(_feeRecipient);
  }

  function setRouter(IDEXRouter _router) external onlyOwner {
    require(address(_router) != address(0), "NFTVillageFeeReceiver: _router is a zero address");
    router = _router;
    emit RouterUpdated(address(_router));
  }

  function setSwapEnabled(bool _enabled) external onlyOwner {
    swapEnabled = _enabled;
    emit SwapUpdated(_enabled);
  }

  function setSwapThreshold(uint256 _threshold) external onlyOwner {
    swapThreshold = _threshold;
    emit SwapThresholdUpdated(_threshold);
  }

  function drainAccidentallySentTokens(
    IERC20 _token,
    address recipient,
    uint256 amount
  ) external onlyOwner {
    _token.transfer(recipient, amount);
  }
}
