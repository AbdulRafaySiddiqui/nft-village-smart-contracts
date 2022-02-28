// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./BaseNFTSale.sol";

contract NFTMultipleGiftClaim is Ownable, AccessControl, BaseNFTSale {
  address public nft;

  mapping(address => bool) public userClaim;

  uint256 internal nonce;

  bytes32 public constant WHITELIST_SIGNER_ROLE = keccak256("WHITELIST_SIGNER_ROLE");
  bytes32 public CONTRIBUTION_TYPEHASH = keccak256("Contribute(address user,uint256 deadline)");
  bytes32 public DOMAIN_SEPARATOR;

  bool public claimEnabled;

  event Claimed(uint256 indexed tokenId, address indexed account);
  event ClaimEnabledUpdated(bool enabled);

  uint256[] public tokenIds;

  constructor(address _nft, uint256[] memory _tokenIds) {
    nft = _nft;
    addTokens(_tokenIds);
    uint256 chainId;
    assembly {
      chainId := chainid()
    }
    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
        keccak256(bytes("NFTVILLAGE_WHITELIST")),
        keccak256(bytes("1")),
        chainId,
        address(this)
      )
    );
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  function addTokens(uint256[] memory _tokeIds) internal {
    for (uint256 i = 0; i < _tokeIds.length; i++) {
      tokenIds.push(_tokeIds[i]);
    }
  }

  function getAllTokenIds() external view returns (uint256[] memory) {
    return tokenIds;
  }

  function claim(
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    require(claimEnabled, "NFTGiftClaim: Claim disabled");
    require(!userClaim[msg.sender], "NFTGiftClaim: ALready Claimed!");
    require(deadline >= block.timestamp, "NFTGiftClaim: Expired");
    require(tokenIds.length > 0, "NFTGiftClaim: Rarities length is zero");

    bytes32 digest = keccak256(
      abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, keccak256(abi.encode(CONTRIBUTION_TYPEHASH, msg.sender, deadline)))
    );
    address signer = ecrecover(digest, v, r, s);

    require(hasRole(WHITELIST_SIGNER_ROLE, signer), "NFTVillageWhitelist: Invalid Signature");

    //randomly select tokenId
    uint256 randomTokenIdIndex = getRandomNumber(0, tokenIds.length - 1);
    uint256 selectedTokenId = tokenIds[randomTokenIdIndex];

    nftTransfer(nft, 1, address(this), msg.sender, selectedTokenId, 1);
    userClaim[msg.sender] = true;

    if (IERC1155(nft).balanceOf(address(this), selectedTokenId) == 0) {
      //Remove selected tokenId from tokeIds list
      tokenIds[randomTokenIdIndex] = tokenIds[tokenIds.length - 1];
      tokenIds.pop();
    }

    emit Claimed(selectedTokenId, msg.sender);
  }

  function getRandomNumber(uint256 min, uint256 max) internal returns (uint256) {
    if (max == 0) return 0;
    return (uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, msg.sender, nonce++))) % max) + min;
  }

  function setClaimEnabled(bool _claimEnabled) external onlyOwner {
    claimEnabled = _claimEnabled;
    emit ClaimEnabledUpdated(_claimEnabled);
  }

  function setNFT(address _nft) external onlyOwner {
    nft = _nft;
  }

  function setSignerRoleAdmin(address admin) external onlyOwner {
    require(admin != address(0), "NFTVillageWhitelist: Invalid admin");
    _setupRole(DEFAULT_ADMIN_ROLE, admin);
  }

  function grandRewardSignerRole(address account) external onlyOwner {
    require(account != address(0), "NFTVillageWhitelist: Invalid account");
    grantRole(WHITELIST_SIGNER_ROLE, account);
  }

  function revokeRewardSignerRole(address account) external onlyOwner {
    revokeRole(WHITELIST_SIGNER_ROLE, account);
  }

  function supportsInterface(bytes4 interfaceId) public view override(ERC1155Receiver, AccessControl) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  function drainAccidentallySentTokens(
    IERC20 token,
    address recipient,
    uint256 amount
  ) external onlyOwner {
    token.transfer(recipient, amount);
  }
}
