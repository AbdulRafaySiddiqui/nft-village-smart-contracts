// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract NFTVillagePrivateSaleClaim is Ownable, AccessControl {
  using SafeERC20 for IERC20;

  IERC20 public token;

  mapping(address => bool) public userClaim;

  bytes32 public constant CLAIM_SIGNER_ROLE = keccak256("CLAIM_SIGNER_ROLE");
  bytes32 public CONTRIBUTION_TYPEHASH = keccak256("Claim(address user,uint256 amount,uint256 deadline)");
  bytes32 public DOMAIN_SEPARATOR;

  bool public claimEnabled;

  event Claimed(uint256 indexed amount, address indexed account);
  event ClaimEnabledUpdated(bool enabled);

  constructor(IERC20 _token) {
    token = _token;

    uint256 chainId;
    assembly {
      chainId := chainid()
    }
    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
        keccak256(bytes("NFTVILLAGE_PRIVATESALE")),
        keccak256(bytes("1")),
        chainId,
        address(this)
      )
    );
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  function claim(
    uint256 deadline,
    uint256 amount,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    require(claimEnabled, "NFTVillagePrivateSaleClaim: Claim disabled");
    require(!userClaim[msg.sender], "NFTVillagePrivateSaleClaim: ALready Claimed!");
    require(deadline >= block.timestamp, "NFTVillagePrivateSaleClaim: Expired");

    bytes32 digest = keccak256(
      abi.encodePacked(
        "\x19\x01",
        DOMAIN_SEPARATOR,
        keccak256(abi.encode(CONTRIBUTION_TYPEHASH, msg.sender, amount, deadline))
      )
    );
    address signer = ecrecover(digest, v, r, s);

    require(hasRole(CLAIM_SIGNER_ROLE, signer), "NFTVillagePrivateSaleClaim: Invalid Signature");

    token.safeTransfer(msg.sender, amount);
    userClaim[msg.sender] = true;
    emit Claimed(amount, msg.sender);
  }

  function setClaimEnabled(bool _claimEnabled) external onlyOwner {
    claimEnabled = _claimEnabled;
    emit ClaimEnabledUpdated(_claimEnabled);
  }

  function setToken(IERC20 _token) external onlyOwner {
    token = _token;
  }

  function setSignerRoleAdmin(address admin) external onlyOwner {
    require(admin != address(0), "NFTVillagePrivateSaleClaim: Invalid admin");
    _setupRole(DEFAULT_ADMIN_ROLE, admin);
  }

  function grandRewardSignerRole(address account) external onlyOwner {
    require(account != address(0), "NFTVillagePrivateSaleClaim: Invalid account");
    grantRole(CLAIM_SIGNER_ROLE, account);
  }

  function revokeRewardSignerRole(address account) external onlyOwner {
    revokeRole(CLAIM_SIGNER_ROLE, account);
  }

  function drainAccidentallySentTokens(
    IERC20 _token,
    address recipient,
    uint256 amount
  ) external onlyOwner {
    _token.transfer(recipient, amount);
  }
}
