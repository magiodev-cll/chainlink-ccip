// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ERC20LockBoxTokenHandler} from "../../../pools/ERC20LockBoxTokenHandler.sol";
import {ERC20LockBoxTokenHandlerSetup} from "./ERC20LockBoxTokenHandlerSetup.t.sol";
import {AuthorizedCallers} from "@chainlink/contracts/src/v0.8/shared/access/AuthorizedCallers.sol";

contract ERC20LockBoxTokenHandler_withdraw is ERC20LockBoxTokenHandlerSetup {
  function test_withdraw_BridgeCaller() public {
    uint256 amount = 1_000e18;
    _deposit(s_bridgeCaller, BRIDGE_CHAIN_SELECTOR, amount);

    vm.startPrank(s_bridgeCaller);

    vm.expectEmit();
    emit ERC20LockBoxTokenHandler.Withdrawal(
      address(s_token), s_bridgeCaller, s_recipient, BRIDGE_CHAIN_SELECTOR, amount
    );

    s_handler.withdraw(address(s_token), BRIDGE_CHAIN_SELECTOR, amount, s_recipient);
    vm.stopPrank();

    assertEq(s_token.balanceOf(s_recipient), amount);
    assertEq(s_token.balanceOf(address(s_handler)), 0);
  }

  function test_withdraw_AdminCallerMax() public {
    uint256 amount = 1_000e18;
    _deposit(s_adminCaller, 0, amount);

    vm.startPrank(s_adminCaller);

    vm.expectEmit();
    emit ERC20LockBoxTokenHandler.Withdrawal(address(s_token), s_adminCaller, s_recipient, 0, amount);

    s_handler.withdraw(address(s_token), 0, type(uint256).max, s_recipient);
    vm.stopPrank();

    assertEq(s_token.balanceOf(s_recipient), amount);
    assertEq(s_token.balanceOf(address(s_handler)), 0);
  }

  function test_withdraw_RevertWhen_BridgeCallerUsesMaxAmount() public {
    _deposit(s_bridgeCaller, BRIDGE_CHAIN_SELECTOR, 1_000e18);

    vm.prank(s_bridgeCaller);
    vm.expectRevert(ERC20LockBoxTokenHandler.MaxAmountOnlyForAdmin.selector);

    s_handler.withdraw(address(s_token), BRIDGE_CHAIN_SELECTOR, type(uint256).max, s_recipient);
  }

  function test_withdraw_RevertWhen_SelectorNotAllowed() public {
    _deposit(s_bridgeCaller, BRIDGE_CHAIN_SELECTOR, 1_000e18);

    vm.prank(s_bridgeCaller);
    vm.expectRevert(abi.encodeWithSelector(ERC20LockBoxTokenHandler.SelectorNotAllowed.selector, OTHER_CHAIN_SELECTOR));

    s_handler.withdraw(address(s_token), OTHER_CHAIN_SELECTOR, 1, s_recipient);
  }

  function test_withdraw_RevertWhen_UnauthorizedCaller() public {
    _deposit(s_bridgeCaller, BRIDGE_CHAIN_SELECTOR, 1_000e18);

    vm.prank(STRANGER);
    vm.expectRevert(abi.encodeWithSelector(AuthorizedCallers.UnauthorizedCaller.selector, STRANGER));

    s_handler.withdraw(address(s_token), BRIDGE_CHAIN_SELECTOR, 1, s_recipient);
  }

  function test_withdraw_RevertWhen_RecipientCannotBeZeroAddress() public {
    _deposit(s_bridgeCaller, BRIDGE_CHAIN_SELECTOR, 1_000e18);

    vm.prank(s_bridgeCaller);
    vm.expectRevert(ERC20LockBoxTokenHandler.RecipientCannotBeZeroAddress.selector);

    s_handler.withdraw(address(s_token), BRIDGE_CHAIN_SELECTOR, 1, address(0));
  }

  function test_withdraw_RevertWhen_InsufficientBalance() public {
    uint256 depositAmount = 1_000e18;
    uint256 withdrawAmount = 1_500e18;
    _deposit(s_bridgeCaller, BRIDGE_CHAIN_SELECTOR, depositAmount);

    vm.prank(s_bridgeCaller);
    vm.expectRevert(
      abi.encodeWithSelector(ERC20LockBoxTokenHandler.InsufficientBalance.selector, withdrawAmount, depositAmount)
    );

    s_handler.withdraw(address(s_token), BRIDGE_CHAIN_SELECTOR, withdrawAmount, s_recipient);
  }

  function test_withdraw_RevertWhen_TokenAmountCannotBeZero() public {
    _deposit(s_bridgeCaller, BRIDGE_CHAIN_SELECTOR, 1_000e18);

    vm.prank(s_bridgeCaller);
    vm.expectRevert(ERC20LockBoxTokenHandler.TokenAmountCannotBeZero.selector);

    s_handler.withdraw(address(s_token), BRIDGE_CHAIN_SELECTOR, 0, s_recipient);
  }
}
