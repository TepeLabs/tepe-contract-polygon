pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title ERC1155CC
 * @author Tepe Labs
 * @notice Extends OpenZeppelin's ERC1155 with extra controls on third party minters
 *         using the creatorsOnly control from OpenSea's ERC1155Tradable 
 *         and implementing a counter so that the token id never has to be passed in
 *
 *         Requires a separate step for creating a new ID and minting --> the creator
 *         controls are only needed if the ID has already been created (so further 
 *         minting)
 */
contract ERC1155CC is ERC1155, Ownable {
  using Strings for string;

  uint256 private _tokenIdCounter;

  mapping (uint256 => address) public creators;
  mapping (uint256 => string) customUri;
  // Contract name
  string public name;
  // Contract symbol
  string public symbol;

  /**
   * @dev Require _msgSender() to be the creator of the token id
   */
  modifier creatorOnly(uint256 _id) {
    require(creators[_id] == _msgSender(), "ERC1155CC#creatorOnly: ONLY_CREATOR_ALLOWED");
    _;
  }

  constructor(
    string memory _name,
    string memory _uri
  ) ERC1155(_uri) {
    name = _name;
  }

  function uri(
    uint256 _id
  ) override public view returns (string memory) {
    require(_exists(_id), "ERC1155Tradable#uri: NONEXISTENT_TOKEN");
    // We have to convert string to bytes to check for existence
    bytes memory customUriBytes = bytes(customUri[_id]);
    if (customUriBytes.length > 0) {
        return customUri[_id];
    } else {
        return super.uri(_id);
    }
  }

  /**
   * @dev Sets a new URI for all token types, by relying on the token type ID
    * substitution mechanism
    * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
   * @param _newURI New URI for all tokens
   */
  function setURI(
    string memory _newURI
  ) public onlyOwner {
    _setURI(_newURI);
  }

  /**
   * @dev Will update the base URI for the token
   * @param _tokenId The token to update. _msgSender() must be its creator.
   * @param _newURI New URI for the token.
   */
  function setCustomURI(
    uint256 _tokenId,
    string memory _newURI
  ) public creatorOnly(_tokenId) {
    customUri[_tokenId] = _newURI;
    emit URI(_newURI, _tokenId);
  }

  /**
    * @dev Creates a new token type and assigns _initialSupply to an address
    * NOTE: remove onlyOwner if you want third parties to create new tokens on
    *       your contract (which may change your IDs)
    * NOTE: The token id must be passed. This allows lazy creation of tokens or
    *       creating NFTs by setting the id's high bits with the method
    *       described in ERC1155 or to use ids representing values other than
    *       successive small integers. If you wish to create ids as successive
    *       small integers you can either subclass this class to count onchain
    *       or maintain the offchain cache of identifiers recommended in
    *       ERC1155 and calculate successive ids from that.
    * @param _initialOwner address of the first owner of the token
    * @param _initialSupply amount to supply the first owner
    * @param _uri Optional URI for this token type
    * @param _data Data to pass if receiver is contract
    * @return The newly created token ID
    */
  function create(
    address _initialOwner,
    uint256 _initialSupply,
    string memory _uri,
    bytes memory _data
  ) public returns (uint256) {
    _tokenIdCounter += 1;
    uint256 _id = _tokenIdCounter;
    creators[_id] = _msgSender();

    if (bytes(_uri).length > 0) {
      customUri[_id] = _uri;
      emit URI(_uri, _id);
    }
    _mint(_initialOwner, _id, _initialSupply, _data);

    return _id;
  }

  /**
    * @dev Mints some amount of tokens to an address
    * @param _to          Address of the future owner of the token
    * @param _id          Token ID to mint
    * @param _quantity    Amount of tokens to mint
    * @param _data        Data to pass if receiver is contract
    */
  function mint(
    address _to,
    uint256 _id,
    uint256 _quantity,
    bytes memory _data
  ) virtual public creatorOnly(_id) {
    _mint(_to, _id, _quantity, _data);
  }

  /**
    * @dev Mint tokens for each id in _ids
    * @param _to          The address to mint tokens to
    * @param _ids         Array of ids to mint
    * @param _quantities  Array of amounts of tokens to mint per id
    * @param _data        Data to pass if receiver is contract
    */
  function batchMint(
    address _to,
    uint256[] memory _ids,
    uint256[] memory _quantities,
    bytes memory _data
  ) public {
    for (uint256 i = 0; i < _ids.length; i++) {
      uint256 _id = _ids[i];
      require(creators[_id] == _msgSender(), "ERC1155CC#batchMint: ONLY_CREATOR_ALLOWED");
    }
    _mintBatch(_to, _ids, _quantities, _data);
  }

  /**
    * @dev Change the creator address for given tokens
    * @param _to   Address of the new creator
    * @param _ids  Array of Token IDs to change creator
    */
  function setCreator(
    address _to,
    uint256[] memory _ids
  ) public {
    require(_to != address(0), "ERC1155CC#setCreator: INVALID_ADDRESS.");
    for (uint256 i = 0; i < _ids.length; i++) {
      uint256 id = _ids[i];
      _setCreator(_to, id);
    }
  }

  
  /**
    * @dev Change the creator address for given token
    * @param _to   Address of the new creator
    * @param _id  Token IDs to change creator of
    */
  function _setCreator(address _to, uint256 _id) internal creatorOnly(_id)
  {
      creators[_id] = _to;
  }

  /**
    * @dev Returns whether the specified token exists by checking to see if it has a creator
    * @param _id uint256 ID of the token to query the existence of
    * @return bool whether the token exists
    */
  function _exists(
    uint256 _id
  ) internal view returns (bool) {
    return creators[_id] != address(0);
  }

  function exists(
    uint256 _id
  ) external view returns (bool) {
    return _exists(_id);
  }
}