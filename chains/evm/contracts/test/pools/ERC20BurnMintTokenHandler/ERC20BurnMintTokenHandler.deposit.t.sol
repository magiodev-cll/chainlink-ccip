// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ITokenHandler} from "../../../interfaces/ITokenHandler.sol";
import {ERC20BurnMintTokenHandler} from "../../../pools/ERC20BurnMintTokenHandler.sol";
import {TokenHandler} from "../../../pools/TokenHandler.sol";
import {ERC20BurnMintTokenHandlerSetup} from "./ERC20BurnMintTokenHandlerSetup.t.sol";
import {AuthorizedCallers} from "@chainlink/contracts/src/v0.8/shared/access/AuthorizedCallers.sol";

contract ERC20BurnMintTokenHandler_deposit is ERC20BurnMintTokenHandlerSetup {
  function test_deposit_BurnsFromBridgeCaller() public {
    uint256 amount = 1_000e18;
    uint256 supplyBefore = s_token.totalSupply();

    vm.startPrank(s_bridgeCaller);
    s_token.approve(address(s_handler), amount);

    vm.expectEmit();
    emit ITokenHandler.Deposit(address(s_token), s_bridgeCaller, BRIDGE_CHAIN_SELECTOR, amount);

    s_handler.deposit(address(s_token), BRIDGE_CHAIN_SELECTOR, amount);
    vm.stopPrank();

    assertEq(s_token.balanceOf(s_bridgeCaller), 9_000e18);
    assertEq(s_token.totalSupply(), supplyBefore - amount);
    assertEq(s_token.balanceOf(address(s_handler)), 0);
  }

  function test_deposit_AdminCaller() public {
    uint256 amount = 1_000e18;

    vm.startPrank(s_adminCaller);
    s_token.approve(address(s_handler), amount);

    vm.expectEmit();
    emit ITokenHandler.Deposit(address(s_token), s_adminCaller, 0, amount);

    s_handler.deposit(address(s_token), 0, amount);
    vm.stopPrank();

    assertEq(s_token.balanceOf(s_adminCaller), 9_000e18);
  }

  function test_deposit_RevertWhen_SelectorNotAllowed() public {
    vm.startPrank(s_bridgeCaller);
    s_token.approve(address(s_handler), 1);
    vm.expectRevert(abi.encodeWithSelector(TokenHandler.SelectorNotAllowed.selector, OTHER_CHAIN_SELECTOR));

    s_handler.deposit(address(s_token), OTHER_CHAIN_SELECTOR, 1);
    vm.stopPrank();
  }

  function test_deposit_RevertWhen_BridgeCallerUsesAdminSelector() public {
    vm.startPrank(s_bridgeCaller);
    s_token.approve(address(s_handler), 1);
    vm.expectRevert(abi.encodeWithSelector(TokenHandler.UnauthorizedAdminCaller.selector, s_bridgeCaller));

    s_handler.deposit(address(s_token), 0, 1);
    vm.stopPrank();
  }

  function test_deposit_RevertWhen_AdminCallerUsesBridgeSelector() public {
    vm.startPrank(s_adminCaller);
    s_token.approve(address(s_handler), 1);
    vm.expectRevert(abi.encodeWithSelector(AuthorizedCallers.UnauthorizedCaller.selector, s_adminCaller));

    s_handler.deposit(address(s_token), BRIDGE_CHAIN_SELECTOR, 1);
    vm.stopPrank();
  }

  function test_deposit_RevertWhen_UnauthorizedCaller() public {
    vm.startPrank(STRANGER);
    vm.expectRevert(abi.encodeWithSelector(AuthorizedCallers.UnauthorizedCaller.selector, STRANGER));

    s_handler.deposit(address(s_token), BRIDGE_CHAIN_SELECTOR, 1);
    vm.stopPrank();
  }

  function test_deposit_RevertWhen_TokenAmountCannotBeZero() public {
    vm.startPrank(s_bridgeCaller);
    s_token.approve(address(s_handler), 1);
    vm.expectRevert(TokenHandler.TokenAmountCannotBeZero.selector);

    s_handler.deposit(address(s_token), BRIDGE_CHAIN_SELECTOR, 0);
    vm.stopPrank();
  }

  function test_deposit_RevertWhen_UnsupportedToken() public {
    vm.startPrank(s_bridgeCaller);
    vm.expectRevert(abi.encodeWithSelector(TokenHandler.UnsupportedToken.selector, address(1)));

    s_handler.deposit(address(1), BRIDGE_CHAIN_SELECTOR, 1);
    vm.stopPrank();
  }

  function test_deposit_RevertWhen_TokenHasNoBurnAllowance() public {
    vm.startPrank(s_bridgeCaller);
    vm.expectRevert();

    s_handler.deposit(address(s_token), BRIDGE_CHAIN_SELECTOR, 1);
    vm.stopPrank();

    assertEq(s_token.balanceOf(s_bridgeCaller), 10_000e18);
  }
}
