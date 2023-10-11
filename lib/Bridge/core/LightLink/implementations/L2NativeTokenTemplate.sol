// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../../../prerequisite/Multisigable.sol";

contract L2NativeTokenTemplate is Initializable, UUPSUpgradeable, Multisigable {
  address public predicate;
  address public rootToken;

  modifier onlyPredicate() {
    require(msg.sender == predicate, "Invalid sender");
    _;
  }

  receive() external payable {}

  function _authorizeUpgrade(address) internal override requireMultisig {}

  function __L2NativeTokenTemplate_init(address _predicate, address _rootToken) internal {
    predicate = _predicate;
    rootToken = _rootToken;
  }

  function initialize(
    address _multisig, //
    address _predicate,
    address _rootToken
  ) public initializer {
    __Multisigable_init(_multisig);
    __L2NativeTokenTemplate_init(_predicate, _rootToken);
  }

  function mint(address user, uint256 amount) external onlyPredicate returns (bool) {
    (bool success, ) = user.call{ value: amount }("");
    return success;
  }

  function burn() public payable onlyPredicate {}
}
