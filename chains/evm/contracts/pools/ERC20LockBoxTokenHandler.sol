// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ITokenHandler} from "../interfaces/ITokenHandler.sol";

import {TokenHandler} from "./TokenHandler.sol";

import {IERC20} from "@openzeppelin/contracts@5.3.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts@5.3.0/token/ERC20/utils/SafeERC20.sol";

/// @notice Token handler that keeps tokens in its own balance until they are withdrawn.
contract ERC20LockBoxTokenHandler is TokenHandler {
  using SafeERC20 for IERC20;

  error InsufficientBalance(uint256 requested, uint256 available);
  error MaxAmountOnlyForAdmin();

  constructor(
    address token
  ) TokenHandler(token) {}

  function typeAndVersion() external pure virtual override returns (string memory) {
    return "ERC20LockBoxTokenHandler 2.1.0";
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
  function getMechanism() external pure override returns (ITokenHandler.Mechanism) {
    return ITokenHandler.Mechanism.LOCK_RELEASE;
  }
}
