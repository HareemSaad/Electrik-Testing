// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// verified
abstract contract Multisigable {
  address public multisig;

  function __Multisigable_init(address _multisig) internal {
    multisig = _multisig;
  }

  /** Modifier */
  // verified
  modifier requireMultisig() {
    require(msg.sender == multisig, "Multisig required");
    _;
  }

  function modifyMultisig(address _multisig) public requireMultisig {
    multisig = _multisig;
  }
}
