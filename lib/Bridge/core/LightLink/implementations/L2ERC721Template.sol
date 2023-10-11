// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "../../../prerequisite/Multisigable.sol";

contract L2ERC721Template is Initializable, UUPSUpgradeable, Multisigable, ERC721Upgradeable {
  address public predicate;
  address public rootToken;

  modifier onlyPredicate() {
    require(msg.sender == predicate, "Invalid sender");
    _;
  }

  function _authorizeUpgrade(address) internal override requireMultisig {}

  function __L2ERC721_init(address _predicate, address _rootToken) internal {
    predicate = _predicate;
    rootToken = _rootToken;
  }

  function initialize(
    address _multisig, //
    address _predicate,
    address _rootToken,
    string memory _name_,
    string memory _symbol_
  ) public initializer {
    __Multisigable_init(_multisig);
    __ERC721_init(_name_, _symbol_);
    __L2ERC721_init(_predicate, _rootToken);
  }

  function mint(address _account, uint256 _tokenId) public onlyPredicate {
    _mint(_account, _tokenId);
  }

  function burn(uint256 _tokenId) public onlyPredicate {
    _burn(_tokenId);
  }
}
