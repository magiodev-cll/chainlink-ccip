// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ITokenHandler} from "../interfaces/ITokenHandler.sol";
import {ITypeAndVersion} from "@chainlink/contracts/src/v0.8/shared/interfaces/ITypeAndVersion.sol";

import {AuthorizedCallers} from "@chainlink/contracts/src/v0.8/shared/access/AuthorizedCallers.sol";

import {IERC20} from "@openzeppelin/contracts@5.3.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts@5.3.0/token/ERC20/utils/SafeERC20.sol";
import {IERC165} from "@openzeppelin/contracts@5.3.0/utils/introspection/IERC165.sol";

/// @notice ERC20 token handler with selector-scoped caller authorization.
/// @dev Bridge callers can only use allowed non-zero selectors; selector zero is reserved for admin and liquidity
/// callers. The pool checks the selector allowlist at configuration time and the handler checks it again on every call.
contract ERC20LockBoxTokenHandler is ITokenHandler, IERC165, ITypeAndVersion, AuthorizedCallers {
  using SafeERC20 for IERC20;

  function typeAndVersion() external pure virtual override returns (string memory) {
    return "ERC20LockBoxTokenHandler 2.1.0";
  }

  error InsufficientBalance(uint256 requested, uint256 available);
  error TokenAmountCannotBeZero();
  error RecipientCannotBeZeroAddress();
  error UnsupportedToken(address token);
  error UnauthorizedAdminCaller(address caller);
  error SelectorNotAllowed(uint64 remoteChainSelector);
  error InvalidChainSelector();
  error MaxAmountOnlyForAdmin();

  event Deposit(address indexed token, address indexed depositor, uint64 indexed remoteChainSelector, uint256 amount);
  event Withdrawal(
    address indexed token, address indexed caller, address indexed recipient, uint64 remoteChainSelector, uint256 amount
  );
  event SelectorAllowedSet(uint64 indexed remoteChainSelector, bool allowed);
  event AdminCallerSet(address indexed caller, bool allowed);

  /// @notice The token supported by this handler.
  IERC20 internal immutable i_token;

  mapping(uint64 remoteChainSelector => bool allowed) private s_allowedSelectors;
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
  function deposit(
    address token,
    uint64 remoteChainSelector,
    uint256 amount
  ) external override {
    _validateDepositWithdraw(token, remoteChainSelector, amount);

    IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

    emit Deposit(token, msg.sender, remoteChainSelector, amount);
  }

  /// @inheritdoc ITokenHandler
  function withdraw(
    address token,
    uint64 remoteChainSelector,
    uint256 amount,
    address recipient
  ) external override {
    _validateDepositWithdraw(token, remoteChainSelector, amount);

    if (recipient == address(0)) {
      revert RecipientCannotBeZeroAddress();
    }

    uint256 balance = IERC20(token).balanceOf(address(this));

    if (amount == type(uint256).max) {
      if (remoteChainSelector != 0) revert MaxAmountOnlyForAdmin();
      amount = balance;
    }
    if (amount > balance) {
      revert InsufficientBalance(amount, balance);
    }

    IERC20(token).safeTransfer(recipient, amount);

    emit Withdrawal(token, msg.sender, recipient, remoteChainSelector, amount);
  }

  /// @inheritdoc ITokenHandler
  function isTokenSupported(
    address token
  ) external view override returns (bool) {
    return address(i_token) == token;
  }

  /// @inheritdoc ITokenHandler
  function isSelectorAllowed(
    uint64 remoteChainSelector
  ) external view override returns (bool) {
    return s_allowedSelectors[remoteChainSelector];
  }

  /// @inheritdoc ITokenHandler
  function getMechanism() external pure override returns (ITokenHandler.Mechanism) {
    return ITokenHandler.Mechanism.LOCK_RELEASE;
  }

  /// @inheritdoc IERC165
  function supportsInterface(
    bytes4 interfaceId
  ) external pure override returns (bool) {
    return interfaceId == type(ITokenHandler).interfaceId || interfaceId == type(IERC165).interfaceId;
  }

  /// @notice Allows or disallows a non-zero bridge selector.
  function setSelectorAllowed(
    uint64 remoteChainSelector,
    bool allowed
  ) external onlyOwner {
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
