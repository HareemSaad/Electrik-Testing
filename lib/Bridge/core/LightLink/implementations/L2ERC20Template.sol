// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "../../../prerequisite/Multisigable.sol";

contract L2ERC20Template is Initializable, UUPSUpgradeable, Multisigable, ERC20Upgradeable {
  uint8 private _decimals;
  address public predicate;
  address public rootToken;

  modifier onlyPredicate() {
    require(msg.sender == predicate, "Invalid sender");
    _;
  }

  function _authorizeUpgrade(address) internal override requireMultisig {}

  function __L2ERC20_init(address _predicate, address _rootToken, uint8 _decimals_) internal {
    predicate = _predicate;
    rootToken = _rootToken;
    _decimals = _decimals_;
  }

  function initialize(
    address _multisig, //
    address _predicate,
    address _rootToken,
    string memory _name_,
    string memory _symbol_,
    uint8 _decimals_
  ) public initializer {
    __Multisigable_init(_multisig);
    __ERC20_init(_name_, _symbol_);
    __L2ERC20_init(_predicate, _rootToken, _decimals_);
  }

  function decimals() public view override returns (uint8) {
    return _decimals;
  }

  function mint(address user, uint256 amount) public onlyPredicate {
    _mint(user, amount);
  }

  function burn(address user, uint256 amount) public onlyPredicate {
    _burn(user, amount);
  }
}
