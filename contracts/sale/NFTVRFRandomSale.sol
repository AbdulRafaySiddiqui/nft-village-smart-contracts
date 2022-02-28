// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "../general/TestVRFConsumerBase.sol";

contract NFTVRFRandomSale is Ownable, ERC721Holder, ERC1155Holder, VRFConsumerBase {
  using SafeERC20 for IERC20;

  enum TokenStandard {
    ERC721,
    ERC1155
  }
  enum OrderStatus {
    Queued,
    Pending,
    Fulfilled
  }

  struct BuyOrder {
    bytes32 requestId;
    uint256 randomness;
    uint256 packId;
    uint256 tokenId;
    address user;
    OrderStatus status;
  }

  struct PackItem {
    uint256 tokenId;
    uint256 weight;
  }

  struct Pack {
    address nft;
    TokenStandard nftType;
    address paymentToken;
    uint256 totalWeight;
    uint256 price;
    bool enabled;
    PackItem[] items;
  }

  bytes32 internal keyHash;
  uint256 internal fee;
  mapping(bytes32 => BuyOrder) public buyOrders;
  mapping(address => BuyOrder[]) public userBuyOrders;

  Pack[] public packs;
  address payable public feeRecipient;

  event PackAdded(uint256 indexed price, bool indexed enabled, PackItem[] indexed items);
  event BuyOrderQueued(bytes32 indexed requestId, uint256 indexed packId, address indexed user);
  event BuyOrderPending(bytes32 indexed requestId, uint256 randomness);
  event BuyOrderFulfilled(bytes32 indexed requestId, address indexed user, uint256 indexed tokenId);

  constructor(
    address payable _feeRecipient,
    address _vrfCoordinator,
    address _link,
    bytes32 _keyHash,
    uint256 _fee
  ) VRFConsumerBase(_vrfCoordinator, _link) {
    feeRecipient = _feeRecipient;
    keyHash = _keyHash;
    fee = _fee;
  }

  function getUserBuyOrders(address user) external view returns (BuyOrder[] memory) {
    return userBuyOrders[user];
  }

  function addPack(
    address nft,
    uint8 nftType,
    address paymentToken,
    uint256 price,
    bool enabled,
    PackItem[] memory items
  ) public onlyOwner {
    require(price > 0, "NFTVillageRandomSale: Invalid Price!");
    require(items.length > 0, "NFTVillageRandomSale: Items must not be empty");

    uint256 totalWeight;
    for (uint256 i = 0; i < items.length; i++) {
      totalWeight = totalWeight + items[i].weight;
    }

    packs.push();
    Pack storage pack = packs[packs.length - 1];
    pack.price = price;
    pack.enabled = enabled;
    pack.totalWeight = totalWeight;
    pack.paymentToken = paymentToken;
    pack.nft = nft;
    pack.nftType = TokenStandard(nftType);

    for (uint256 i = 0; i < items.length; i++) {
      pack.items.push(items[i]);
    }

    emit PackAdded(price, enabled, items);
  }

  function setPackEnabled(uint256 packId, bool enabled) external onlyOwner {
    require(packs.length > packId, "NFTVillageRandomSale: Invalid Pack Id");
    packs[packId].enabled = enabled;
  }

  function setPackPrice(uint256 packId, uint256 price) external onlyOwner {
    packs[packId].price = price;
  }

  function setFeeRecipient(address payable _feeRecipient) external onlyOwner {
    feeRecipient = _feeRecipient;
  }

  function getPackInfo(uint256 packId) external view returns (Pack memory) {
    return packs[packId];
  }

  function buyPack(uint256 packId) external payable {
    Pack storage pack = packs[packId];
    require(pack.enabled, "NFTVillageRandomSale: Pack disabled!");

    if (address(pack.paymentToken) == address(0)) {
      require(pack.price == msg.value, "NFTVillageRandomSale: Invalid amount");
      feeRecipient.transfer(pack.price);
    } else {
      IERC20(pack.paymentToken).safeTransferFrom(msg.sender, feeRecipient, pack.price);
    }

    bytes32 requestId = requestRandomness(keyHash, fee);
    BuyOrder memory order = BuyOrder({
      requestId: requestId,
      packId: packId,
      user: msg.sender,
      status: OrderStatus.Queued,
      tokenId: 0,
      randomness: 0
    });

    buyOrders[requestId] = order;
    userBuyOrders[msg.sender].push(order);

    emit BuyOrderQueued(requestId, packId, msg.sender);
  }

  function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
    BuyOrder storage order = buyOrders[requestId];
    order.status = OrderStatus.Pending;
    order.randomness = randomness;

    emit BuyOrderPending(requestId, randomness);
  }

  function claimNFT(bytes32 requestId) external {
    BuyOrder storage order = buyOrders[requestId];
    require(order.status == OrderStatus.Pending, "NFTVillageRandomSale: Already fulfilled!");
    Pack storage pack = packs[order.packId];

    uint256[] memory tokenIds = getTokenIdsProbabilityList(pack.totalWeight, pack.items);
    uint256 randomIndex = getRandomNumberInRange(order.randomness, 0, pack.totalWeight - 1);
    uint256 tokenId = tokenIds[randomIndex];
    order.tokenId = tokenId;

    nftTransfer(pack.nft, uint8(pack.nftType), address(this), order.user, tokenId);
    emit BuyOrderFulfilled(requestId, order.user, tokenId);
  }

  function nftTransfer(
    address nft,
    uint8 nftType,
    address from,
    address to,
    uint256 tokenId
  ) internal {
    if (TokenStandard(nftType) == TokenStandard.ERC721) {
      IERC721(nft).safeTransferFrom(from, to, tokenId);
    } else if (TokenStandard(nftType) == TokenStandard.ERC1155) {
      IERC1155(nft).safeTransferFrom(from, to, tokenId, 1, "");
    } else {
      require(false, "NFTVillageRandomSale: Unsupported TokenStandard");
    }
  }

  function getTokenIdsProbabilityList(uint256 totalWeight, PackItem[] memory items)
    internal
    pure
    returns (uint256[] memory)
  {
    uint256[] memory tokenIds = new uint256[](totalWeight);
    uint256 index;
    for (uint256 i = 0; i < items.length; i++) {
      for (uint256 j = 0; j < items[i].weight; j++) {
        tokenIds[index++] = items[i].tokenId;
      }
    }
    return tokenIds;
  }

  function getRandomNumberInRange(
    uint256 random,
    uint256 min,
    uint256 max
  ) internal pure returns (uint256) {
    return (random % max) + min;
  }
}
