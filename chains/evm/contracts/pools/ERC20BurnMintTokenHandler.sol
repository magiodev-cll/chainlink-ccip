// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IBurnMintERC20} from "../interfaces/IBurnMintERC20.sol";
import {ITokenHandler} from "../interfaces/ITokenHandler.sol";

import {BurnMintTokenHandlerBase} from "./BurnMintTokenHandlerBase.sol";

/// @notice Token handler that burns on deposit and mints on withdrawal.
contract ERC20BurnMintTokenHandler is BurnMintTokenHandlerBase {
  error MaxAmountNotSupported();

  constructor(
    address token
  ) BurnMintTokenHandlerBase(token) {}

  function typeAndVersion() external pure virtual override returns (string memory) {
    return "ERC20BurnMintTokenHandler 2.0.0";
  }

  /// @inheritdoc ITokenHandler
  function deposit(
    address token,
    uint64 remoteChainSelector,
    uint256 amount
  ) external override {
    _validateDepositWithdraw(token, remoteChainSelector, amount);
    _recordBurn(remoteChainSelector, amount);

    IBurnMintERC20(token).burnFrom(msg.sender, amount);

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
    if (amount == type(uint256).max) {
      revert MaxAmountNotSupported();
    }

    _recordMint(remoteChainSelector, amount);
    IBurnMintERC20(token).mint(recipient, amount);

    emit Withdrawal(token, msg.sender, recipient, remoteChainSelector, amount);
  }

  /// @inheritdoc ITokenHandler
  function getMechanism() external pure override returns (ITokenHandler.Mechanism) {
    return ITokenHandler.Mechanism.BURN_MINT;
  }
}
