// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ITokenHandler} from "../interfaces/ITokenHandler.sol";
import {ITypeAndVersion} from "@chainlink/contracts/src/v0.8/shared/interfaces/ITypeAndVersion.sol";

import {AuthorizedCallers} from "@chainlink/contracts/src/v0.8/shared/access/AuthorizedCallers.sol";

import {IERC20} from "@openzeppelin/contracts@5.3.0/token/ERC20/IERC20.sol";
import {IERC165} from "@openzeppelin/contracts@5.3.0/utils/introspection/IERC165.sol";

/// @notice Shared authorization for token handlers.
/// @dev Bridge callers can only use allowed non-zero selectors; selector zero is reserved for admin and liquidity
/// callers. The pool checks the selector allowlist at configuration time and the handler checks it again on every call.
abstract contract TokenHandler is ITokenHandler, IERC165, ITypeAndVersion, AuthorizedCallers {
  /// @notice Thrown when a deposit or withdrawal amount is zero.
  error TokenAmountCannotBeZero();

  /// @notice Thrown when a withdrawal recipient is the zero address.
  error RecipientCannotBeZeroAddress();

  /// @notice Thrown when the token is not the handler's supported token.
  error UnsupportedToken(address token);

  /// @notice Thrown when a caller is not allowed to use selector zero.
  error UnauthorizedAdminCaller(address caller);

  /// @notice Thrown when a bridge caller uses a selector that is not allowed.
  error SelectorNotAllowed(uint64 remoteChainSelector);

  /// @notice Thrown when a chain selector is invalid.
  error InvalidChainSelector();

  /// @notice Emitted when a selector's allowlist status is updated.
  event SelectorAllowedSet(uint64 indexed remoteChainSelector, bool allowed);

  /// @notice Emitted when an admin caller is added or removed.
  event AdminCallerSet(address indexed caller, bool allowed);

  /// @notice The token supported by this handler.
  IERC20 internal immutable i_token;

  /// @dev Selectors on which bridge callers may use this handler.
  mapping(uint64 remoteChainSelector => bool allowed) private s_allowedSelectors;

  /// @dev Callers allowed to use selector zero for admin and liquidity operations.
  mapping(address caller => bool allowed) private s_adminCallers;

  constructor(
    address token
  ) AuthorizedCallers(new address[](0)) {
    if (token == address(0)) {
      revert ZeroAddressNotAllowed();
    }

    i_token = IERC20(token);
  }

  /// @inheritdoc ITokenHandler
  function isTokenSupported(
    address token
  ) public view override returns (bool) {
    return address(i_token) == token;
  }

  /// @inheritdoc ITokenHandler
  function isSelectorAllowed(
    uint64 remoteChainSelector
  ) public view override returns (bool) {
    return s_allowedSelectors[remoteChainSelector];
  }

  /// @inheritdoc IERC165
  function supportsInterface(
    bytes4 interfaceId
  ) public pure virtual override returns (bool) {
    return interfaceId == type(ITokenHandler).interfaceId || interfaceId == type(IERC165).interfaceId;
  }

  /// @notice Allows or disallows a non-zero bridge selector.
  function setSelectorAllowed(
    uint64 remoteChainSelector,
    bool allowed
  ) public virtual onlyOwner {
    if (remoteChainSelector == 0) revert InvalidChainSelector();

    s_allowedSelectors[remoteChainSelector] = allowed;
    emit SelectorAllowedSet(remoteChainSelector, allowed);
  }

  /// @notice Grants or revokes admin and liquidity access for selector zero.
  function setAdminCaller(
    address caller,
    bool allowed
  ) external onlyOwner {
    if (caller == address(0)) revert ZeroAddressNotAllowed();

    s_adminCallers[caller] = allowed;
    emit AdminCallerSet(caller, allowed);
  }

  /// @notice Returns the token held by this handler.
  function getToken() external view returns (IERC20) {
    return i_token;
  }

  /// @notice Returns whether a caller can use selector zero.
  function isAdminCaller(
    address caller
  ) external view returns (bool) {
    return s_adminCallers[caller];
  }

  function _validateDepositWithdraw(
    address token,
    uint64 remoteChainSelector,
    uint256 amount
  ) internal view {
    if (amount == 0) revert TokenAmountCannotBeZero();
    if (token != address(i_token)) revert UnsupportedToken(token);

    _validateSelectorAndCaller(remoteChainSelector);
  }

  function _validateSelectorAndCaller(
    uint64 remoteChainSelector
  ) internal view {
    if (remoteChainSelector == 0) {
      if (!s_adminCallers[msg.sender]) revert UnauthorizedAdminCaller(msg.sender);
      return;
    }

    _validateCaller();
    if (!s_allowedSelectors[remoteChainSelector]) revert SelectorNotAllowed(remoteChainSelector);
  }
}
