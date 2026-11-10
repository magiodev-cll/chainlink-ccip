// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {TokenHandler} from "./TokenHandler.sol";

import {Math} from "@openzeppelin/contracts@5.3.0/utils/math/Math.sol";

/// @notice Net issuance accounting shared by burn-mint token handlers.
/// @dev Every bridge selector keeps gross minted and burned counters plus a net outstanding allowance. The net
/// outstanding amount is minted minus burned, so burns create credit for future mints and mints create credit for
/// future burns.
/// @dev Caps are initial allowances, not gross lifetime limits. A zero cap is valid on one side because the opposite
/// counter can still provide credit, but both caps zero on a selector with no traffic leaves it unable to move. A hub
/// lane needs a burn allowance for its first outbound transfer; a remote lane needs a mint allowance for its first
/// inbound transfer. Selector zero is the trusted admin and liquidity path and is neither capped nor counted.
abstract contract BurnMintTokenHandlerBase is TokenHandler {
  // ================================================================
  // │                      Errors and events                        │
  // ================================================================

  /// @notice Thrown when enabling a selector with both caps zero, which leaves it unable to move a token.
  error CapsNotSet(uint64 remoteChainSelector);

  /// @notice Thrown when a mint would exceed the selector's net outstanding mint cap.
  error MintCapExceeded(uint64 remoteChainSelector, uint256 requested, uint256 available);

  /// @notice Thrown when a burn would exceed the selector's net outstanding burn cap.
  error BurnCapExceeded(uint64 remoteChainSelector, uint256 requested, uint256 available);

  /// @notice Emitted when a selector's initial mint and burn caps are configured.
  event SelectorCapsSet(uint64 indexed remoteChainSelector, uint256 mintCap, uint256 burnCap);

  // ================================================================
  // │                            Storage                            │
  // ================================================================

  /// @dev Gross lifetime amount minted for the selector. Updated before the external mint call.
  mapping(uint64 remoteChainSelector => uint256 minted) private s_minted;

  /// @dev Gross lifetime amount burned for the selector. Updated before the external burn call.
  mapping(uint64 remoteChainSelector => uint256 burned) private s_burned;

  /// @dev Initial mint allowance for the selector. Net minted is minted minus burned.
  mapping(uint64 remoteChainSelector => uint256 mintCap) private s_mintCaps;

  /// @dev Initial burn allowance for the selector. Net burned is burned minus minted.
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

  /// @notice Configures the initial mint and burn caps for a bridge selector.
  /// @dev The caps are initial allowances, not gross lifetime limits. Net minted is minted minus burned and net
  /// burned is burned minus minted. A zero cap is valid on one side, but both zero on a selector with no traffic
  /// leaves it unable to move, so it cannot be enabled. A hub lane needs a burn allowance for its first outbound
  /// transfer; a remote lane needs a mint allowance for its first inbound transfer. Changing a cap does not reset the
  /// counters, and lowering a cap below current net usage blocks further operations in that direction until the cap
  /// is raised. Once a selector is enabled, setting both caps to zero stops new flow but still allows return flow
  /// against existing credit.
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

  /// @notice Returns the gross minted and burned amounts plus the configured initial caps for a selector.
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

  /// @dev Enabling a selector requires at least one nonzero cap, because both zero leaves it unable to move a token.
  /// Disabling is always allowed and does not reset the caps or counters.
  function _validateSelectorAllowed(
    uint64 remoteChainSelector,
    bool allowed
  ) internal view override {
    if (allowed && s_mintCaps[remoteChainSelector] == 0 && s_burnCaps[remoteChainSelector] == 0) {
      revert CapsNotSet(remoteChainSelector);
    }
  }

  /// @dev Checks and updates the gross mint counter before the external mint call. Selector zero is skipped because
  /// the admin path is uncapped and uncounted.
  function _recordMint(
    uint64 remoteChainSelector,
    uint256 amount
  ) internal {
    if (remoteChainSelector == 0) return;

    uint256 available =
      _getAvailable(s_minted[remoteChainSelector], s_burned[remoteChainSelector], s_mintCaps[remoteChainSelector]);
    if (amount > available) revert MintCapExceeded(remoteChainSelector, amount, available);

    s_minted[remoteChainSelector] += amount;
  }

  /// @dev Checks and updates the gross burn counter before the external burn call. Selector zero is skipped because
  /// the admin path is uncapped and uncounted.
  function _recordBurn(
    uint64 remoteChainSelector,
    uint256 amount
  ) internal {
    if (remoteChainSelector == 0) return;

    uint256 available =
      _getAvailable(s_burned[remoteChainSelector], s_minted[remoteChainSelector], s_burnCaps[remoteChainSelector]);
    if (amount > available) revert BurnCapExceeded(remoteChainSelector, amount, available);

    s_burned[remoteChainSelector] += amount;
  }

  /// @dev Returns the amount available in one direction. `used` is the same-direction counter, `credit` is the
  /// opposite-direction counter, and `cap` is the initial allowance. Burning credits minting and minting credits
  /// burning, so reusable lanes do not need cap raises after every round trip.
  function _getAvailable(
    uint256 used,
    uint256 credit,
    uint256 cap
  ) private pure returns (uint256) {
    if (cap == type(uint256).max) return type(uint256).max;

    return credit >= used ? Math.saturatingAdd(cap, credit - used) : Math.saturatingSub(cap, used - credit);
  }
}
