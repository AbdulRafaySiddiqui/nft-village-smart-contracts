// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./BaseNFTSale.sol";

contract NFTGiftClaim is Ownable, AccessControl, BaseNFTSale {
  address public nft;
  uint256 public constant NFT_ID = 0;
  mapping(address => bool) public userClaim;

  bytes32 public constant WHITELIST_SIGNER_ROLE = keccak256("WHITELIST_SIGNER_ROLE");
  bytes32 public CONTRIBUTION_TYPEHASH = keccak256("Contribute(address user,uint256 deadline)");
  bytes32 public DOMAIN_SEPARATOR;

  bool public claimEnabled;

  event Claimed(address indexed account);
  event ClaimEnabledUpdated(bool enabled);

  constructor(address _nft) {
    nft = _nft;

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

  function claim(
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    require(claimEnabled, "NFTGiftClaim: Claim disabled");
    require(!userClaim[msg.sender], "NFTGiftClaim: ALready Claimed!");

    require(deadline >= block.timestamp, "NFTVillageWhitelist: Expired");
    bytes32 digest = keccak256(
      abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, keccak256(abi.encode(CONTRIBUTION_TYPEHASH, msg.sender, deadline)))
    );
    address signer = ecrecover(digest, v, r, s);

    require(hasRole(WHITELIST_SIGNER_ROLE, signer), "NFTVillageWhitelist: Invalid Signature");

    nftTransfer(nft, 1, address(this), msg.sender, NFT_ID, 1);
    userClaim[msg.sender] = true;

    emit Claimed(msg.sender);
  }

  function canClaim(address account) external view returns (bool) {
    return userClaim[account];
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
