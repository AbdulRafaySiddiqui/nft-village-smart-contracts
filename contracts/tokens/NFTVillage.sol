// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "../interfaces/INFTVillageFeeReceiver.sol";
import "./NFTVillageFeeReceiver.sol";

contract NFTVillage is Context, Ownable, ERC20 {
  address public minter;
  INFTVillageFeeReceiver public feeReceiver;
  address public pair;

  mapping(address => bool) public taxless;
  mapping(address => uint256) public unlocksAt;

  uint256 public buyFee;
  uint256 public sellFee;
  uint256 public burnFee;

  event MinterUpdated(address indexed minter);
  event FeeReceiverUpdated(address indexed feeReceiver);
  event PairUpdated(address indexed pair);
  event FeeUpdated(uint256 indexed buyFee, uint256 indexed sellFee, uint256 indexed burnFee);

  uint256 public constant FEE_DENOMINATOR = 10000;

  modifier onlyMinter() {
    require(minter == _msgSender(), "NFTVillage: Only minter!");
    _;
  }

  constructor(address _minter, address _router) ERC20("NFTVillage", "NV") {
    require(_minter != address(0) && _router != address(0), "NFTVillage: zero address");

    minter = _minter;
    feeReceiver = new NFTVillageFeeReceiver(address(this), _router, msg.sender);

    taxless[address(feeReceiver)] = true;
    taxless[_minter] = true;
    taxless[address(this)] = true;
    taxless[msg.sender] = true;

    emit MinterUpdated(_minter);
    emit FeeReceiverUpdated(address(feeReceiver));
  }

  function mint(address account, uint256 amount) external onlyMinter {
    _mint(account, amount);
  }

  function _transfer(
    address sender,
    address recipient,
    uint256 amount
  ) internal override {
    uint256 amountToTransfer = amount;

    require(unlocksAt[sender] < block.timestamp, "NFTVillage: Tokens are locked!");

    if (!taxless[sender] && !taxless[recipient]) {
      if (address(feeReceiver) != address(0) && pair != address(0)) {
        uint256 fee;
        if (buyFee != 0 && sender == pair) {
          fee = (amount * buyFee) / FEE_DENOMINATOR;
        } else if (sellFee != 0 && recipient == pair) {
          fee = (amount * sellFee) / FEE_DENOMINATOR;
        }
        if (fee != 0) {
          amountToTransfer -= fee;
          super._transfer(sender, address(this), fee);
          super._approve(address(this), address(feeReceiver), fee);
          feeReceiver.onFeeReceived(address(this), fee);
        }
      }

      if (burnFee != 0) {
        uint256 _burnFee = (amount * burnFee) / FEE_DENOMINATOR;
        amountToTransfer -= _burnFee;
        super._burn(sender, _burnFee);
      }
    }

    super._transfer(sender, recipient, amountToTransfer);
  }

  function setPair(address _pair) external onlyOwner {
    require(_pair != address(0), "NFTVillage: _pair is a zero address");
    pair = _pair;
    emit PairUpdated(_pair);
  }

  function setMinter(address _minter) external onlyOwner {
    require(_minter != address(0), "NFTVillage: _minter is a zero address");
    minter = _minter;
    emit MinterUpdated(minter);
  }

  function setFee(
    uint256 _buyFee,
    uint256 _sellFee,
    uint256 _burnFee
  ) external onlyOwner {
    require(_buyFee <= 1000 && _sellFee <= 1000 && _burnFee <= 1000, "NFTVillage: Fee out of range!");
    buyFee = _buyFee;
    sellFee = _sellFee;
    burnFee = _burnFee;

    emit FeeUpdated(buyFee, sellFee, burnFee);
  }

  function setFeeReciever(INFTVillageFeeReceiver _feeRecipient) external onlyOwner {
    require(address(_feeRecipient) != address(0), "NFTVillage: _feeRecipient is a zero address");
    feeReceiver = _feeRecipient;
    emit FeeReceiverUpdated(address(_feeRecipient));
  }

  function setTaxless(address account, bool hasTax) external onlyOwner {
    require(account != address(0), "NFTVillage: account is a zero address");
    taxless[account] = hasTax;
  }

  // Locking tokens of wallet can be used to pay employees in token,
  // developement or marketing team and unlock at a certain time
  function setWalletLock(address account, uint256 unlockTimestamp) external onlyOwner {
    require(account != address(0), "NFTVillage: account is a zero address");
    unlocksAt[account] = unlockTimestamp;
  }
}
