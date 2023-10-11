// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// import proxy instance
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// proxy instance
contract BridgeProxy is ERC1967Proxy {
  constructor(address _logic, bytes memory _data) ERC1967Proxy(_logic, _data) {}
}
