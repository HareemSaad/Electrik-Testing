// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../../../libs/Create2.sol";
import "../../../prerequisite/Multisigable.sol";
import "./IL2Predicate.sol";
import "../../Common/IBridgeRegistry.sol";
import "../../Proxy/TokenProxy.sol";

contract L2NativeTokenPredicate is
  Initializable, //
  UUPSUpgradeable,
  Multisigable,
  IL2Predicate
{
  using ECDSA for bytes32;

  // variables
  address public bridgeRegistry;
  address public implTemplate;
  mapping(address => address) public l1ToL2Gateway;

  mapping(address => uint256) public counter;
  mapping(address => mapping(uint256 => bool)) public orderExecuted;
  mapping(address => mapping(uint256 => mapping(address => bool))) public isConfirmed;

  event TokenMapped(bytes32 messageHash);
  event WithdrawToken(bytes message);
  event DepositToken(bytes32 messageHash);

  function __L2NativeTokenPredicate_init(address _registry, address _impl) internal {
    bridgeRegistry = _registry;
    implTemplate = _impl;
  }

  function initialize(address _multisig, address _registry, address _impl) public initializer {
    __Multisigable_init(_multisig);
    __L2NativeTokenPredicate_init(_registry, _impl);
  }

  function _authorizeUpgrade(address) internal override requireMultisig {}

  /* Views */

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
    // get bytecode without constructor
    childToken = Create2.createClone2(salt, type(TokenProxy).creationCode);

    // call initialize using call
    (bool success, bytes memory data) = childToken.call(
      abi.encodeWithSignature(
        "initialize(address,bytes)", //
        implTemplate,
        // encode function data for initialize
        abi.encodeWithSignature("initialize(address,address,address)", multisig, address(this), l1Token)
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
    _initiateWithdraw(l1ToL2Gateway[address(0)], msg.sender, msg.sender, msg.value);
  }

  // verified
  function withdraw(address _l2Token) external payable {
    _initiateWithdraw(_l2Token, msg.sender, msg.sender, msg.value);
  }

  // verified
  function withdrawTo(address _l2Token, address _to) external payable {
    _initiateWithdraw(_l2Token, msg.sender, _to, msg.value);
  }

  // verified
  function _initiateWithdraw(address _l2Token, address _from, address _to, uint256 _amount) internal {
    require(_amount > 0, "Not enough amount");
    require(_to != address(0), "Invalid address");
    require(_l2Token != address(0), "Invalid token");

    (bool success, bytes memory data) = _l2Token.call(abi.encodeWithSignature("rootToken()"));
    require(success, "rootToken failed");
    address l1Token = abi.decode(data, (address));
    require(l1ToL2Gateway[l1Token] == _l2Token, "Token not mapped");

    (bool success2, ) = _l2Token.call{ value: _amount }(abi.encodeWithSignature("burn()"));
    require(success2, "burn failed");

    uint256 counter_ = counter[_from];

    emit WithdrawToken(abi.encode(_from, counter_, l1Token, _l2Token, _to, _amount));
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
    (address from, uint256 orderId, address l1Token, address l2Token, address to, uint256 amount) = abi.decode(_data, (address, uint256, address, address, address, uint256));
    require(amount > 0, "Not enough amount");
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

    (bool success, bytes memory data) = l2Token.call(abi.encodeWithSignature("mint(address,uint256)", to, amount));

    bool isMinted = abi.decode(data, (bool));
    require(success && isMinted, "mint failed");

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
