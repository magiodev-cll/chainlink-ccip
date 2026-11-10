// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ITokenHandler} from "../interfaces/ITokenHandler.sol";
import {ITypeAndVersion} from "@chainlink/contracts/src/v0.8/shared/interfaces/ITypeAndVersion.sol";

import {TokenPool} from "./TokenPool.sol";

import {IERC20} from "@openzeppelin/contracts@5.3.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts@5.3.0/token/ERC20/utils/SafeERC20.sol";

/// @notice Token pool used for tokens on their native chain. This uses a lock and release mechanism.
/// @dev One token per LockReleaseTokenPool.
contract LockReleaseTokenPool is TokenPool, ITypeAndVersion {
  using SafeERC20 for IERC20;

  function typeAndVersion() external pure virtual override returns (string memory) {
    return "LockReleaseTokenPool 2.0.0";
  }

  error InvalidTokenHandler(address tokenHandler);

  /// @notice The token handler for the token pool.
  ITokenHandler internal immutable i_tokenHandler;

  constructor(
    IERC20 token,
    uint8 localTokenDecimals,
    address advancedPoolHooks,
    address rmnProxy,
    address router,
    address tokenHandler
  ) TokenPool(token, localTokenDecimals, advancedPoolHooks, rmnProxy, router) {
    if (tokenHandler == address(0)) revert ZeroAddressInvalid();

    ITokenHandler handler = ITokenHandler(tokenHandler);
    if (!handler.isTokenSupported(address(token))) {
      revert InvalidToken(address(token));
    }
    if (handler.getMechanism() != ITokenHandler.Mechanism.LOCK_RELEASE) {
      revert InvalidTokenHandler(tokenHandler);
    }
    token.forceApprove(tokenHandler, type(uint256).max);
    i_tokenHandler = handler;
  }

  /// @notice Gets the token handler address.
  function getTokenHandler() external view returns (address) {
    return address(i_tokenHandler);
  }

  /// @inheritdoc TokenPool
  /// @dev The router has already transferred the full amount to this contract before calling lockOrBurn.
  /// For V1 the amount = full amount. For V2 the amount = destTokenAmount (after fees), and fees remain on this contract.
  function _lockOrBurn(
    uint64 remoteChainSelector,
    uint256 amount
  ) internal override {
    i_tokenHandler.deposit(address(i_token), remoteChainSelector, amount);
  }

  /// @inheritdoc TokenPool
  /// @dev Releases tokens from the token handler to the receiver.
  function _releaseOrMint(
    address receiver,
    uint256 amount,
    uint64 remoteChainSelector
  ) internal override {
    i_tokenHandler.withdraw(address(i_token), remoteChainSelector, amount, receiver);
  }
}
