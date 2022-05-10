// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../exchange/IHasSecondarySaleFees.sol";
import "./NFTVillageCardFeatures.sol";

pragma solidity ^0.8.0;

contract NFTVillageERC721 is IHasSecondarySaleFees, Context, Ownable, NFTVillageCardFeatures, ERC721 {
  /*
   * bytes4(keccak256('getFeeBps(uint256)')) == 0x0ebd4c7f
   * bytes4(keccak256('getFeeRecipients(uint256)')) == 0xb9c4d9fb
   *
   * => 0x0ebd4c7f ^ 0xb9c4d9fb == 0xb7799584
   */
  bytes4 internal constant SECONDARY_FEE_INTERFACE_ID = 0xb7799584;

  struct Fee {
    address payable recipient;
    uint256 value;
  }

  string _uri;
  uint256 public nextTokenId;
  mapping(uint256 => Fee[]) public fees;
  mapping(uint256 => address) public creators;

  event SecondarySaleFees(uint256 tokenId, address[] recipients, uint256[] bps);

  constructor(
    string memory _name,
    string memory _symbol,
    string memory uri
  ) ERC721(_name, _symbol) {
    _uri = uri;
  }

  function getFeeRecipients(uint256 id) external view override returns (address payable[] memory) {
    Fee[] memory _fees = fees[id];
    address payable[] memory result = new address payable[](_fees.length);
    for (uint256 i = 0; i < _fees.length; i++) {
      result[i] = _fees[i].recipient;
    }
    return result;
  }

  function getFeeBps(uint256 id) external view override returns (uint256[] memory) {
    Fee[] memory _fees = fees[id];
    uint256[] memory result = new uint256[](_fees.length);
    for (uint256 i = 0; i < _fees.length; i++) {
      result[i] = _fees[i].value;
    }
    return result;
  }

  function addSecondaryFee(uint256 _id, Fee[] memory _fees) internal {
    creators[_id] = msg.sender;
    address[] memory recipients = new address[](_fees.length);
    uint256[] memory bps = new uint256[](_fees.length);
    for (uint256 i = 0; i < _fees.length; i++) {
      require(_fees[i].recipient != address(0x0), "Recipient should be present");
      require(_fees[i].value != 0, "Fee value should be positive");
      fees[_id].push(_fees[i]);
      recipients[i] = _fees[i].recipient;
      bps[i] = _fees[i].value;
    }
    if (_fees.length > 0) {
      emit SecondarySaleFees(_id, recipients, bps);
    }
  }

  function mint(address _to, Fee[] memory _fees) external onlyOwner {
    _safeMint(_to, nextTokenId);
    addSecondaryFee(nextTokenId++, _fees);
  }

  function mint(
    address _to,
    uint256 _id,
    Fee[] memory _fees
  ) external onlyOwner {
    require(_id < nextTokenId, "Invalid Token ID");
    _safeMint(_to, _id);
    addSecondaryFee(_id, _fees);
  }

  function setUri(string memory uri) external onlyOwner {
    _uri = uri;
  }

  function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
    return interfaceId == SECONDARY_FEE_INTERFACE_ID || super.supportsInterface(interfaceId);
  }

  function _baseURI() internal view override returns (string memory) {
    return _uri;
  }
}
