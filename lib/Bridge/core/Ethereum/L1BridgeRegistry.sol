// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { IBridgeRegistry, ValidatorSet } from "../Common/IBridgeRegistry.sol";
import { Multisigable } from "../../prerequisite/Multisigable.sol";

contract L1BridgeRegistry is Initializable, UUPSUpgradeable, ReentrancyGuard, Multisigable, IBridgeRegistry {
  using ECDSA for bytes32;
  using ValidatorSet for ValidatorSet.Record;

  // variables
  uint256 public consensusPowerThreshold;
  ValidatorSet.Record internal validators;

  // example
  // bytes32 private constant WETH_TOKEN = keccak256("weth_token");
  mapping(bytes32 => address) public implementations;

  function __L1BridgeRegistry_init() internal {
    validators.add(0x574f879160252895a4b15fF9316bf9e9ADc46423, 50);
    validators.add(0x2681682d1197131D339a169dF10940470D602806, 20);
    consensusPowerThreshold = 70;
  }

  function initialize(address _multisig) public initializer {
    __Multisigable_init(_multisig);
    __L1BridgeRegistry_init();
  }

  function _authorizeUpgrade(address) internal override requireMultisig {}

  /* Views */
  // verified
  function getValidators() public view returns (ValidatorSet.Validator[] memory) {
    return validators.values;
  }

  // verified
  function validValidator(address _validator) public view returns (bool) {
    return validators.contains(_validator);
  }

  // verified
  function getPower(address _validator) public view returns (uint256) {
    return validators.getPower(_validator);
  }

  function getServiceImplementation(bytes32 _key) public view returns (address) {
    return implementations[_key];
  }

  /* Admin */
  // verified
  function modifyConsensusPowerThreshold(uint256 _amount) public requireMultisig {
    consensusPowerThreshold = _amount;
  }

  // verified
  function modifyValidators(address[] memory _validators, uint256[] memory _powers) public requireMultisig {
    for (uint256 i = 0; i < _validators.length; i++) {
      validators.modify(_validators[i], _powers[i]);
    }
  }

  // verified
  function removeValidators(address[] memory _accounts) public requireMultisig {
    for (uint256 i = 0; i < _accounts.length; i++) {
      validators.remove(_accounts[i]);
    }
  }

  // verified
  function modifyServiceImplementations(bytes32[] memory _keys, address[] memory _implementations) public requireMultisig {
    for (uint256 i = 0; i < _keys.length; i++) {
      implementations[_keys[i]] = _implementations[i];
    }
  }
}
