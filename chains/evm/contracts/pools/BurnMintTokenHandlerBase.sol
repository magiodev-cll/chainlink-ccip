// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {TokenHandler} from "./TokenHandler.sol";

/// @notice Lifetime issuance accounting shared by burn-mint token handlers.
/// @dev Caps apply only to bridge selectors. Selector zero is the trusted admin and liquidity path and is
/// neither capped nor counted. A zero cap disables minting or burning for that selector until the owner raises it.
abstract contract BurnMintTokenHandlerBase is TokenHandler {
  error MintCapExceeded(uint64 remoteChainSelector, uint256 requested, uint256 available);
  error BurnCapExceeded(uint64 remoteChainSelector, uint256 requested, uint256 available);

  event SelectorCapsSet(uint64 indexed remoteChainSelector, uint256 mintCap, uint256 burnCap);

  mapping(uint64 remoteChainSelector => uint256 minted) private s_minted;
  mapping(uint64 remoteChainSelector => uint256 burned) private s_burned;
  mapping(uint64 remoteChainSelector => uint256 mintCap) private s_mintCaps;
  mapping(uint64 remoteChainSelector => uint256 burnCap) private s_burnCaps;

  constructor(
    address token
  ) TokenHandler(token) {}

  /// @notice Sets the lifetime mint and burn caps for a bridge selector.
  /// @dev A zero cap disables the operation for that selector. Use type(uint256).max for unlimited.
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

  /// @notice Returns the lifetime minted and burned amounts plus the configured caps for a selector.
  /// @dev Selector zero returns zero values because the admin path is neither capped nor counted.
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
