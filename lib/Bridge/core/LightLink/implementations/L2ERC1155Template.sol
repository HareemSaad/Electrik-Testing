// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "../../../prerequisite/Multisigable.sol";

contract L2ERC1155Template is Initializable, UUPSUpgradeable, Multisigable, ERC1155Upgradeable {
  address public predicate;
  address public rootToken;

  modifier onlyPredicate() {
    require(msg.sender == predicate, "Invalid sender");
    _;
  }

  function _authorizeUpgrade(address) internal override requireMultisig {}

  function __L2ERC20_init(address _predicate, address _rootToken) internal {
    predicate = _predicate;
    rootToken = _rootToken;
  }

  function initialize(
    address _multisig, //
    address _predicate,
    address _rootToken
  ) public initializer {
    __Multisigable_init(_multisig);
    __ERC1155_init("");
    __L2ERC20_init(_predicate, _rootToken);
  }

  function mint(address _account, uint256 _id, uint256 _amount, bytes memory _data) public onlyPredicate {
    _mint(_account, _id, _amount, _data);
  }

  function mintBatch(address _account, uint256[] memory _ids, uint256[] memory _amounts, bytes memory data) public onlyPredicate {
    _mintBatch(_account, _ids, _amounts, data);
  }

  function burn(address _account, uint256 _id, uint256 _amount) public onlyPredicate {
    _burn(_account, _id, _amount);
  }

  function burnBatch(address _account, uint256[] memory _ids, uint256[] memory _amounts) public onlyPredicate {
    _burnBatch(_account, _ids, _amounts);
  }
}
