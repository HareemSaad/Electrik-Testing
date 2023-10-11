// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "../../../libs/Create2.sol";
import "../../../prerequisite/Multisigable.sol";
import "./IL2Predicate.sol";
import "../../Common/IBridgeRegistry.sol";
import "../../Proxy/TokenProxy.sol";

contract L2ERC1155Predicate is
  Initializable, //
  UUPSUpgradeable,
  EIP712Upgradeable,
  Multisigable,
  IL2Predicate
{
  using ECDSA for bytes32;

  struct WithdrawalForwardRequest {
    uint256 nonce;
    address l1Token;
    address from;
    address to;
    uint256[] ids;
    uint256[] amounts;
  }

  // variables
  bytes32 private _STRUCT_HASH;
  address public bridgeRegistry;
  address public implTemplate;
  mapping(address => address) public l1ToL2Gateway;

  mapping(address => uint256) public counter;
  mapping(address => mapping(uint256 => bool)) public orderExecuted;
  mapping(address => mapping(uint256 => mapping(address => bool))) public isConfirmed;

  event TokenMapped(bytes32 messageHash);
  event WithdrawToken(bytes message);
  event DepositToken(bytes32 messageHash);

  function __L1ERC1155Predicate_init(address _registry, address _impl) internal {
    _STRUCT_HASH = keccak256("WithdrawalForwardRequest(uint256 nonce,address l1Token,address from,address to,uint256[] ids,uint256[] amounts)");
    bridgeRegistry = _registry;
    implTemplate = _impl;
  }

  function initialize(address _multisig, address _registry, address _impl) public initializer {
    __EIP712_init("Lightlink", "1.0.0");
    __Multisigable_init(_multisig);
    __L1ERC1155Predicate_init(_registry, _impl);
  }

  function _authorizeUpgrade(address) internal override requireMultisig {}

  function buildDomainSeparatorV4(bytes32 typeHash, bytes32 nameHash, bytes32 versionHash) internal view returns (bytes32) {
    // sig from ethereum chain
    uint256 chainid = 1;
    return keccak256(abi.encode(typeHash, nameHash, versionHash, chainid, address(this)));
  }

  function domainSeparatorV4() internal view returns (bytes32) {
    bytes32 typeHash = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    return buildDomainSeparatorV4(typeHash, _EIP712NameHash(), _EIP712VersionHash());
  }

  function _hashTypedDataV4(bytes32 structHash) internal view virtual override returns (bytes32) {
    return ECDSAUpgradeable.toTypedDataHash(domainSeparatorV4(), structHash);
  }

  /* Views */
  function verify(WithdrawalForwardRequest calldata req, bytes calldata signature) public view returns (bool) {
    address signer = _hashTypedDataV4(keccak256(abi.encode(_STRUCT_HASH, req.nonce, req.l1Token, req.from, req.to, keccak256(abi.encodePacked(req.ids)), keccak256(abi.encodePacked(req.amounts))))).recover(signature);
    return signer == req.from;
  }

  /* Execute */
  function modifyImplTemplate(address _template) public requireMultisig {
    implTemplate = _template;
  }

  function mapToken(address[] memory _currentValidators, bytes[] memory _signatures, bytes memory _message) public {
    (address from, uint256 orderId, address l1Token) = abi.decode(_message, (address, uint256, address));

    // get root to child token
    address childToken = l1ToL2Gateway[l1Token];

    require(!orderExecuted[from][orderId], "Already executed");

    // check if it's already mapped
    require(childToken == address(0x0), "Already mapped");
    bytes32 messageHash = keccak256(abi.encodePacked(block.chainid, _message));
    _checkValidatorSignatures(
      from,
      orderId,
      _currentValidators,
      _signatures,
      // Get hash of the transaction batch and checkpoint
      messageHash,
      IBridgeRegistry(bridgeRegistry).consensusPowerThreshold()
    );

    orderExecuted[from][orderId] = true;

    // deploy new child token
    bytes32 salt = keccak256(abi.encodePacked(l1Token));
    childToken = Create2.createClone2(salt, type(TokenProxy).creationCode);

    // call initialize using call
    (bool success, bytes memory data) = childToken.call(
      abi.encodeWithSignature(
        "initialize(address,bytes)", //
        implTemplate,
        // encode function data for initialize
        abi.encodeWithSignature(
          "initialize(address,address,address)",
          multisig, //
          address(this),
          l1Token
        )
      )
    );

    require(success, string(data));

    // map the token
    l1ToL2Gateway[l1Token] = childToken;
    emit TokenMapped(messageHash);
  }

  /*************************
   * Deposits *
   *************************/
  // verified
  receive() external payable {
    revert("Not supported");
  }

  // verified
  function withdraw(address _l2Token, uint256[] memory _tokenIds, uint256[] memory _amounts) external payable {
    _initiateWithdraw(_l2Token, msg.sender, msg.sender, _tokenIds, _amounts);
  }

  // verified
  function withdrawTo(address _l2Token, address _to, uint256[] memory _tokenIds, uint256[] memory _amounts) external payable {
    _initiateWithdraw(_l2Token, msg.sender, _to, _tokenIds, _amounts);
  }

  function delegacyWithdraw(WithdrawalForwardRequest calldata req, bytes calldata signature) external {
    require(counter[req.from] == req.nonce, "Invalid nonce");
    require(verify(req, signature), "Invalid signature");
    address l2Token = l1ToL2Gateway[req.l1Token];
    _initiateWithdraw(l2Token, req.from, req.to, req.ids, req.amounts);
  }

  // verified
  function _initiateWithdraw(address _l2Token, address _from, address _to, uint256[] memory _tokenIds, uint256[] memory _amounts) internal {
    require(_tokenIds.length == _amounts.length, "Input mismatch");
    require(_tokenIds.length > 0, "No token");
    require(_to != address(0), "Invalid address");
    require(_l2Token != address(0), "Invalid token");

    bool success;
    bytes memory data;
    (success, data) = _l2Token.call(abi.encodeWithSignature("rootToken()"));
    require(success, "ERC1155 rootToken failed");
    address l1Token = abi.decode(data, (address));
    require(l1ToL2Gateway[l1Token] == _l2Token, "Token not mapped");

    // burn using call
    (success, ) = _l2Token.call(abi.encodeWithSignature("burnBatch(address,uint256[],uint256[])", _from, _tokenIds, _amounts));
    require(success, "ERC1155 burn failed");

    uint256 counter_ = counter[_from];

    emit WithdrawToken(abi.encode(_from, counter_, l1Token, _l2Token, _to, _tokenIds, _amounts));
    counter[_from]++;
  }

  /*************************
   * Withdrawals *
   *************************/

  // verified
  function syncDeposit(
    address[] memory _currentValidators,
    bytes[] memory _signatures,
    // transaction data
    bytes memory _data
  ) external {
    (address from, uint256 orderId, address l1Token, address l2Token, address to, uint256[] memory ids, uint256[] memory amounts) = abi.decode(_data, (address, uint256, address, address, address, uint256[], uint256[]));
    require(ids.length == amounts.length, "Input mismatch");
    require(ids.length > 0, "No token");
    require(to != address(0), "Invalid address");
    require(!orderExecuted[from][orderId], "Order already executed");
    require(_currentValidators.length == _signatures.length, "Input mismatch");
    require(l1ToL2Gateway[l1Token] == l2Token, "Invalid token gateway");

    bytes32 messageHash = keccak256(abi.encodePacked(block.chainid, _data));
    _checkValidatorSignatures(
      from,
      orderId,
      _currentValidators,
      _signatures,
      // Get hash of the transaction batch and checkpoint
      messageHash,
      IBridgeRegistry(bridgeRegistry).consensusPowerThreshold()
    );

    orderExecuted[from][orderId] = true;

    (bool success, ) = l2Token.call(abi.encodeWithSignature("mintBatch(address,uint256[],uint256[],bytes)", to, ids, amounts, ""));
    require(success, "ERC1155 mint failed");

    emit DepositToken(messageHash);
  }

  /* Internal */
  function _checkValidatorSignatures(address _from, uint256 _orderId, address[] memory _currentValidators, bytes[] memory _signatures, bytes32 _messageHash, uint256 _powerThreshold) private {
    uint256 cumulativePower = 0;
    // check no dupicate validator

    for (uint256 i = 0; i < _currentValidators.length; i++) {
      address signer = _messageHash.toEthSignedMessageHash().recover(_signatures[i]);
      require(signer == _currentValidators[i], "Validator signature does not match.");
      require(IBridgeRegistry(bridgeRegistry).validValidator(signer), "Invalid validator");
      require(!isConfirmed[_from][_orderId][signer], "No duplicate validator");

      // prevent double-signing attacks
      isConfirmed[_from][_orderId][signer] = true;

      // Sum up cumulative power
      cumulativePower += IBridgeRegistry(bridgeRegistry).getPower(signer);

      // Break early to avoid wasting gas
      if (cumulativePower > _powerThreshold) {
        break;
      }
    }

    // Check that there was enough power
    require(cumulativePower >= _powerThreshold, "Submitted validator set signatures do not have enough power.");
    // Success
  }
}
