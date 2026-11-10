// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IExternalMinter} from "../interfaces/IExternalMinter.sol";
import {ITokenHandler} from "../interfaces/ITokenHandler.sol";

import {TokenHandler} from "./TokenHandler.sol";

import {IERC20} from "@openzeppelin/contracts@5.3.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts@5.3.0/token/ERC20/utils/SafeERC20.sol";

/// @notice Token handler that burns and mints through an external minter.
/// @dev The minter owns the token supply, so this handler moves tokens to itself before calling the minter's burn.
contract ERC20ExternalMinterTokenHandler is TokenHandler {
  using SafeERC20 for IERC20;

  error MinterTokenMismatch(address token, address minterToken);
  error MaxAmountNotSupported();
  error ExternalMinterCallFailed(address minter);

  IExternalMinter internal immutable i_minter;

  constructor(
    address token,
    address minter
  ) TokenHandler(token) {
    if (minter == address(0)) revert ZeroAddressNotAllowed();

    i_minter = IExternalMinter(minter);

    address minterToken = IExternalMinter(minter).getToken();
    if (minterToken != token) revert MinterTokenMismatch(token, minterToken);
  }

  function typeAndVersion() external pure virtual override returns (string memory) {
    return "ERC20ExternalMinterTokenHandler 2.0.0";
  }

  /// @notice Returns the external minter used by this handler.
  function getMinter() external view returns (IExternalMinter) {
    return i_minter;
  }

  /// @inheritdoc ITokenHandler
  function deposit(
    address token,
    uint64 remoteChainSelector,
    uint256 amount
  ) external override {
    _validateDepositWithdraw(token, remoteChainSelector, amount);

    IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    IERC20(token).forceApprove(address(i_minter), amount);

    if (!i_minter.burn(amount)) revert ExternalMinterCallFailed(address(i_minter));

    if (IERC20(token).allowance(address(this), address(i_minter)) != 0) {
      IERC20(token).forceApprove(address(i_minter), 0);
    }

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

    if (!i_minter.mint(recipient, amount)) revert ExternalMinterCallFailed(address(i_minter));

    emit Withdrawal(token, msg.sender, recipient, remoteChainSelector, amount);
  }

  /// @inheritdoc ITokenHandler
  function getMechanism() external pure override returns (ITokenHandler.Mechanism) {
    return ITokenHandler.Mechanism.BURN_MINT;
  }
}
