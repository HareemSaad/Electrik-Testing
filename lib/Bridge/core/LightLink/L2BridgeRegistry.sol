// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { IBridgeRegistry, ValidatorSet } from "../Common/IBridgeRegistry.sol";
import "../../prerequisite/Multisigable.sol";

contract L2BridgeRegistry is Initializable, UUPSUpgradeable, Multisigable, ReentrancyGuardUpgradeable, IBridgeRegistry {
  using ECDSA for bytes32;
  using ValidatorSet for ValidatorSet.Record;

  // variables
  uint256 public consensusPowerThreshold;
  ValidatorSet.Record internal validators;

  // example
  // bytes32 private constant STAKE_MANAGER = keccak256("stakeManager");
  mapping(bytes32 => address) public implementations;

  function __L2BridgeRegistry_init() internal {
    validators.add(0x9d90c8906d04056f67953F975cB5B7B4c492b2d2, 50);
    validators.add(0x59f0C3147B3eBE237c2E23F24D4D79036d9DEBf0, 20);
    consensusPowerThreshold = 70;
  }
  
  function initialize(address _multisig) public initializer {
    __Multisigable_init(_multisig);
    __L2BridgeRegistry_init();
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

  // verified
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
