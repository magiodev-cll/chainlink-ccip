// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Token movement interface for a siloed pool.
interface ITokenHandler {
  enum Mechanism {
    LOCK_RELEASE,
    BURN_MINT,
    CUSTOM
  }

  function deposit(
    address token,
    uint64 remoteChainSelector,
    uint256 amount
  ) external;

  function withdraw(
    address token,
    uint64 remoteChainSelector,
    uint256 amount,
    address recipient
  ) external;

  function isTokenSupported(
    address token
  ) external view returns (bool);

  function isSelectorAllowed(
    uint64 remoteChainSelector
  ) external view returns (bool);

  function getMechanism() external view returns (Mechanism);
}
