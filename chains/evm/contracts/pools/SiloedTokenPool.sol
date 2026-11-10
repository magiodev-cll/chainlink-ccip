// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ITokenHandler} from "../interfaces/ITokenHandler.sol";
import {ITypeAndVersion} from "@chainlink/contracts/src/v0.8/shared/interfaces/ITypeAndVersion.sol";

import {TokenPool} from "./TokenPool.sol";

import {IERC20} from "@openzeppelin/contracts@5.3.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts@5.3.0/token/ERC20/utils/SafeERC20.sol";
import {EnumerableMap} from "@openzeppelin/contracts@5.3.0/utils/structs/EnumerableMap.sol";

/// @notice A variation on Lock Release token pools where liquidity is shared among some chains, and stored independently
/// for others. Chains which do not share liquidity are known as siloed chains.
contract SiloedTokenPool is TokenPool, ITypeAndVersion {
  using SafeERC20 for IERC20;
  using EnumerableMap for EnumerableMap.UintToAddressMap;

  function typeAndVersion() external pure virtual override returns (string memory) {
    return "SiloedTokenPool 2.0.0";
  }

  error TokenHandlerNotConfigured(uint64 remoteChainSelector);
  error TokenHandlerSelectorNotAllowed(uint64 remoteChainSelector, address tokenHandler);

  event TokenHandlerConfigured(uint64 indexed remoteChainSelector, address indexed tokenHandler);

  struct TokenHandlerConfig {
    uint64 remoteChainSelector;
    address tokenHandler;
  }

  /// @notice Token handlers keyed by chain selector.
  /// @dev We can have a many-to-one mapping of remote chain selectors to token handlers. This allows for chains to share or isolate liquidity.
  EnumerableMap.UintToAddressMap internal s_tokenHandlers;

  constructor(
    IERC20 token,
    uint8 localTokenDecimals,
    address advancedPoolHooks,
    address rmnProxy,
    address router
  ) TokenPool(token, localTokenDecimals, advancedPoolHooks, rmnProxy, router) {}

  /// @inheritdoc TokenPool
  /// @dev Deposits the amount into the token handler configured for the remote chain selector.
  function _lockOrBurn(
    uint64 remoteChainSelector,
    uint256 amount
  ) internal override {
    ITokenHandler tokenHandler = getTokenHandler(remoteChainSelector);

    // Token handlers trust pools but pools don't necessarily trust token handlers, so we need to approve each time.
    i_token.forceApprove(address(tokenHandler), amount);
    tokenHandler.deposit(address(i_token), remoteChainSelector, amount);
    // We reset to 0 to reduce the risk of dangling approvals being exploited. It should already be 0 but just in case.
    if (i_token.allowance(address(this), address(tokenHandler)) != 0) {
      i_token.forceApprove(address(tokenHandler), 0);
    }
  }

  /// @inheritdoc TokenPool
  /// @dev Withdraws from the token handler configured for the remote chain selector after a liquidity check.
  function _releaseOrMint(
    address receiver,
    uint256 amount,
    uint64 remoteChainSelector
  ) internal override {
    getTokenHandler(remoteChainSelector).withdraw(address(i_token), remoteChainSelector, amount, receiver);
  }

  /// @notice Returns all configured token handlers.
  /// @return tokenHandlerConfigs Array of all configured token handler configurations.
  function getAllTokenHandlerConfigs() external view returns (TokenHandlerConfig[] memory tokenHandlerConfigs) {
    uint256 length = s_tokenHandlers.length();
    tokenHandlerConfigs = new TokenHandlerConfig[](length);
    for (uint256 i = 0; i < length; ++i) {
      (uint256 chainSelector, address tokenHandler) = s_tokenHandlers.at(i);
      tokenHandlerConfigs[i] =
        TokenHandlerConfig({remoteChainSelector: uint64(chainSelector), tokenHandler: tokenHandler});
    }
    return tokenHandlerConfigs;
  }

  /// @notice Configure token handlers.
  /// @param tokenHandlerConfigs The token handler configurations to set.
  function configureTokenHandlers(
    TokenHandlerConfig[] calldata tokenHandlerConfigs
  ) public virtual onlyOwner {
    for (uint256 i = 0; i < tokenHandlerConfigs.length; ++i) {
      address tokenHandler = tokenHandlerConfigs[i].tokenHandler;
      if (tokenHandler == address(0)) revert ZeroAddressInvalid();

      if (!ITokenHandler(tokenHandler).isTokenSupported(address(i_token))) {
        revert InvalidToken(address(i_token));
      }

      if (!ITokenHandler(tokenHandler).isSelectorAllowed(tokenHandlerConfigs[i].remoteChainSelector)) {
        revert TokenHandlerSelectorNotAllowed(tokenHandlerConfigs[i].remoteChainSelector, tokenHandler);
      }

      s_tokenHandlers.set(tokenHandlerConfigs[i].remoteChainSelector, tokenHandler);
      emit TokenHandlerConfigured(tokenHandlerConfigs[i].remoteChainSelector, tokenHandler);
    }
  }

  /// @notice Gets the token handler for a given remote chain selector.
  /// @param remoteChainSelector The remote chain selector to get the token handler for.
  function getTokenHandler(
    uint64 remoteChainSelector
  ) public view returns (ITokenHandler) {
    (bool exists, address tokenHandler) = s_tokenHandlers.tryGet(remoteChainSelector);
    if (!exists) revert TokenHandlerNotConfigured(remoteChainSelector);
    return ITokenHandler(tokenHandler);
  }
}
