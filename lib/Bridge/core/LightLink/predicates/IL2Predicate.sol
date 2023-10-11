// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IL2Predicate {
  /* Events */
  function implTemplate() external view returns (address);

  function mapToken(address[] memory _currentValidators, bytes[] memory _signatures, bytes memory _message) external;
}
