// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice External minter used by tokens whose supply is controlled outside the token contract.
interface IExternalMinter {
  function getToken() external view returns (address);

  function mint(
    address recipient,
    uint256 amount
  ) external returns (bool);

  function burn(
    uint256 amount
  ) external returns (bool);
}
