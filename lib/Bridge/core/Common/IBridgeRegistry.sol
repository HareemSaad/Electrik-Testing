// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import "../../libs/ValidatorSet.sol";

interface IBridgeRegistry {
  /* Views */
  function consensusPowerThreshold() external view returns (uint256);

  function validValidator(address) external view returns (bool);

  function getPower(address) external view returns (uint256);

  function getValidators() external view returns (ValidatorSet.Validator[] memory);

  function getServiceImplementation(bytes32) external view returns (address);

  /* Actions */
  function modifyConsensusPowerThreshold(uint256 _amount) external;

  function modifyValidators(address[] memory _accounts, uint256[] memory _powers) external;

  function removeValidators(address[] memory _accounts) external;

  function modifyServiceImplementations(bytes32[] memory _serviceId, address[] memory _implementations) external;
}
