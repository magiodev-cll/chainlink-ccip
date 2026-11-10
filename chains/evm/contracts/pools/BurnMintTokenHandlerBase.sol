// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {TokenHandler} from "./TokenHandler.sol";

/// @notice Lifetime issuance accounting shared by burn-mint token handlers.
/// @dev Every bridge selector has gross lifetime minted and burned counters. The counters are always updated and
/// are intended for monitoring, reporting, and reconciliation.
/// @dev Mint and burn caps are optional enforcement on top of the counters. Setting a cap to
/// type(uint256).max makes that direction accounting-only; setting it to zero disables the direction. Caps are
/// gross lifetime limits: burning does not free mint capacity, and changing a cap does not reset its counter.
/// @dev Selector zero is the trusted admin and liquidity path. It is neither capped nor counted.
abstract contract BurnMintTokenHandlerBase is TokenHandler {
  // ================================================================
  // │                      Errors and events                        │
  // ================================================================

  /// @notice Thrown when enabling a selector without both issuance caps configured.
  error CapsNotSet(uint64 remoteChainSelector);

  /// @notice Thrown when a mint would exceed the selector's lifetime mint cap.
  error MintCapExceeded(uint64 remoteChainSelector, uint256 requested, uint256 available);

  /// @notice Thrown when a burn would exceed the selector's lifetime burn cap.
  error BurnCapExceeded(uint64 remoteChainSelector, uint256 requested, uint256 available);

  /// @notice Emitted when a selector's lifetime mint and burn caps are updated.
  event SelectorCapsSet(uint64 indexed remoteChainSelector, uint256 mintCap, uint256 burnCap);

  // ================================================================
  // │                            Storage                            │
  // ================================================================

  /// @dev Gross lifetime amount minted for the selector. Updated before the external mint call.
  mapping(uint64 remoteChainSelector => uint256 minted) private s_minted;

  /// @dev Gross lifetime amount burned for the selector. Updated before the external burn call.
  mapping(uint64 remoteChainSelector => uint256 burned) private s_burned;

  /// @dev Gross lifetime mint cap for the selector. Zero disables minting; type(uint256).max is an explicit
  /// accounting-only setting.
  mapping(uint64 remoteChainSelector => uint256 mintCap) private s_mintCaps;

  /// @dev Gross lifetime burn cap for the selector. Zero disables burning; type(uint256).max is an explicit
  /// accounting-only setting.
  mapping(uint64 remoteChainSelector => uint256 burnCap) private s_burnCaps;

  // ================================================================
  // │                         Construction                          │
  // ================================================================

  constructor(
    address token
  ) TokenHandler(token) {}

  // ================================================================
  // │                       External setters                        │
  // ================================================================

  /// @inheritdoc TokenHandler
  /// @dev Enabling a selector requires both caps to be nonzero because caps default to zero. Disabling is always
  /// allowed and does not reset the accounting or the caps.
  function setSelectorAllowed(
    uint64 remoteChainSelector,
    bool allowed
  ) public override onlyOwner {
    if (allowed && (s_mintCaps[remoteChainSelector] == 0 || s_burnCaps[remoteChainSelector] == 0)) {
      revert CapsNotSet(remoteChainSelector);
    }

    super.setSelectorAllowed(remoteChainSelector, allowed);
  }

  /// @notice Sets the gross lifetime mint and burn caps for a bridge selector.
  /// @dev A zero cap disables that direction. Use type(uint256).max for accounting-only operation. Changing a cap
  /// does not reset the lifetime counter. Lowering a cap below the amount already used blocks further operations in
  /// that direction until the cap is raised.
  function setSelectorCaps(
    uint64 remoteChainSelector,
    uint256 mintCap,
    uint256 burnCap
  ) external onlyOwner {
    if (remoteChainSelector == 0) revert InvalidChainSelector();

    s_mintCaps[remoteChainSelector] = mintCap;
    s_burnCaps[remoteChainSelector] = burnCap;

    emit SelectorCapsSet(remoteChainSelector, mintCap, burnCap);
  }

  // ================================================================
  // │                           Read path                           │
  // ================================================================

  /// @notice Returns the gross lifetime minted and burned amounts plus the configured caps for a selector.
  /// @dev The counters are only updated by bridge traffic. Selector zero returns zero values because the admin path
  /// is neither capped nor counted.
  function getSelectorAccounting(
    uint64 remoteChainSelector
  ) external view returns (uint256 minted, uint256 burned, uint256 mintCap, uint256 burnCap) {
    return (
      s_minted[remoteChainSelector],
      s_burned[remoteChainSelector],
      s_mintCaps[remoteChainSelector],
      s_burnCaps[remoteChainSelector]
    );
  }

  // ================================================================
  // │                       Internal helpers                        │
  // ================================================================

  /// @dev Checks and updates the gross lifetime mint counter before the external mint call. Selector zero is
  /// skipped because the admin path is uncapped and uncounted.
  function _recordMint(
    uint64 remoteChainSelector,
    uint256 amount
  ) internal {
    if (remoteChainSelector == 0) return;

    uint256 cap = s_mintCaps[remoteChainSelector];
    uint256 minted = s_minted[remoteChainSelector];
    uint256 available = minted >= cap ? 0 : cap - minted;
    if (amount > available) revert MintCapExceeded(remoteChainSelector, amount, available);

    s_minted[remoteChainSelector] = minted + amount;
  }

  /// @dev Checks and updates the gross lifetime burn counter before the external burn call. Selector zero is
  /// skipped because the admin path is uncapped and uncounted.
  function _recordBurn(
    uint64 remoteChainSelector,
    uint256 amount
  ) internal {
    if (remoteChainSelector == 0) return;

    uint256 cap = s_burnCaps[remoteChainSelector];
    uint256 burned = s_burned[remoteChainSelector];
    uint256 available = burned >= cap ? 0 : cap - burned;
    if (amount > available) revert BurnCapExceeded(remoteChainSelector, amount, available);

    s_burned[remoteChainSelector] = burned + amount;
  }
}
