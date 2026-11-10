// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ITokenHandler} from "../../../interfaces/ITokenHandler.sol";
import {ERC20ExternalMinterTokenHandler} from "../../../pools/ERC20ExternalMinterTokenHandler.sol";
import {TokenHandler} from "../../../pools/TokenHandler.sol";
import {ERC20ExternalMinterTokenHandlerSetup} from "./ERC20ExternalMinterTokenHandlerSetup.t.sol";
import {AuthorizedCallers} from "@chainlink/contracts/src/v0.8/shared/access/AuthorizedCallers.sol";

contract ERC20ExternalMinterTokenHandler_withdraw is ERC20ExternalMinterTokenHandlerSetup {
  function test_withdraw_MintsThroughMinter() public {
    uint256 amount = 1_000e18;
    uint256 supplyBefore = s_token.totalSupply();

    vm.startPrank(s_bridgeCaller);
    vm.expectEmit();
    emit ITokenHandler.Withdrawal(address(s_token), s_bridgeCaller, s_recipient, BRIDGE_CHAIN_SELECTOR, amount);

    s_handler.withdraw(address(s_token), BRIDGE_CHAIN_SELECTOR, amount, s_recipient);
    vm.stopPrank();

    assertEq(s_token.balanceOf(s_recipient), amount);
    assertEq(s_token.totalSupply(), supplyBefore + amount);
  }

  function test_withdraw_AdminCaller() public {
    uint256 amount = 1_000e18;

    vm.startPrank(s_adminCaller);
    s_handler.withdraw(address(s_token), 0, amount, s_recipient);
    vm.stopPrank();

    assertEq(s_token.balanceOf(s_recipient), amount);
  }

  function test_withdraw_RevertWhen_MaxAmount() public {
    vm.startPrank(s_bridgeCaller);
    vm.expectRevert(ERC20ExternalMinterTokenHandler.MaxAmountNotSupported.selector);

    s_handler.withdraw(address(s_token), BRIDGE_CHAIN_SELECTOR, type(uint256).max, s_recipient);
    vm.stopPrank();
  }

  function test_withdraw_RevertWhen_SelectorNotAllowed() public {
    vm.startPrank(s_bridgeCaller);
    vm.expectRevert(abi.encodeWithSelector(TokenHandler.SelectorNotAllowed.selector, OTHER_CHAIN_SELECTOR));

    s_handler.withdraw(address(s_token), OTHER_CHAIN_SELECTOR, 1, s_recipient);
    vm.stopPrank();
  }

  function test_withdraw_RevertWhen_UnauthorizedCaller() public {
    vm.startPrank(STRANGER);
    vm.expectRevert(abi.encodeWithSelector(AuthorizedCallers.UnauthorizedCaller.selector, STRANGER));

    s_handler.withdraw(address(s_token), BRIDGE_CHAIN_SELECTOR, 1, s_recipient);
    vm.stopPrank();
  }

  function test_withdraw_RevertWhen_RecipientCannotBeZeroAddress() public {
    vm.startPrank(s_bridgeCaller);
    vm.expectRevert(TokenHandler.RecipientCannotBeZeroAddress.selector);

    s_handler.withdraw(address(s_token), BRIDGE_CHAIN_SELECTOR, 1, address(0));
    vm.stopPrank();
  }

  function test_withdraw_RevertWhen_TokenAmountCannotBeZero() public {
    vm.startPrank(s_bridgeCaller);
    vm.expectRevert(TokenHandler.TokenAmountCannotBeZero.selector);

    s_handler.withdraw(address(s_token), BRIDGE_CHAIN_SELECTOR, 0, s_recipient);
    vm.stopPrank();
  }
}
