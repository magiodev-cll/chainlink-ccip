// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ERC20LockBoxTokenHandler} from "../../../pools/ERC20LockBoxTokenHandler.sol";
import {BaseERC20} from "../../../tokens/BaseERC20.sol";
import {CrossChainToken} from "../../../tokens/CrossChainToken.sol";
import {ERC20LockBoxTokenHandlerSetup} from "./ERC20LockBoxTokenHandlerSetup.t.sol";
import {AuthorizedCallers} from "@chainlink/contracts/src/v0.8/shared/access/AuthorizedCallers.sol";

contract ERC20LockBoxTokenHandler_deposit is ERC20LockBoxTokenHandlerSetup {
  function test_deposit_BridgeCaller() public {
    uint256 amount = 1_000e18;

    vm.startPrank(s_bridgeCaller);
    s_token.approve(address(s_handler), amount);

    vm.expectEmit();
    emit ERC20LockBoxTokenHandler.Deposit(address(s_token), s_bridgeCaller, BRIDGE_CHAIN_SELECTOR, amount);

    s_handler.deposit(address(s_token), BRIDGE_CHAIN_SELECTOR, amount);
    vm.stopPrank();

    assertEq(s_token.balanceOf(address(s_handler)), amount);
  }

  function test_deposit_AdminCaller() public {
    uint256 amount = 1_000e18;

    vm.startPrank(s_adminCaller);
    s_token.approve(address(s_handler), amount);

    vm.expectEmit();
    emit ERC20LockBoxTokenHandler.Deposit(address(s_token), s_adminCaller, 0, amount);

    s_handler.deposit(address(s_token), 0, amount);
    vm.stopPrank();

    assertEq(s_token.balanceOf(address(s_handler)), amount);
  }

  function test_deposit_RevertWhen_SelectorNotAllowed() public {
    uint256 amount = 1_000e18;

    vm.startPrank(s_bridgeCaller);
    s_token.approve(address(s_handler), amount);
    vm.expectRevert(abi.encodeWithSelector(ERC20LockBoxTokenHandler.SelectorNotAllowed.selector, OTHER_CHAIN_SELECTOR));

    s_handler.deposit(address(s_token), OTHER_CHAIN_SELECTOR, amount);
    vm.stopPrank();
  }

  function test_deposit_RevertWhen_BridgeCallerUsesAdminSelector() public {
    uint256 amount = 1_000e18;

    vm.startPrank(s_bridgeCaller);
    s_token.approve(address(s_handler), amount);
    vm.expectRevert(abi.encodeWithSelector(ERC20LockBoxTokenHandler.UnauthorizedAdminCaller.selector, s_bridgeCaller));

    s_handler.deposit(address(s_token), 0, amount);
    vm.stopPrank();
  }

  function test_deposit_RevertWhen_AdminCallerUsesBridgeSelector() public {
    uint256 amount = 1_000e18;

    vm.startPrank(s_adminCaller);
    s_token.approve(address(s_handler), amount);
    vm.expectRevert(abi.encodeWithSelector(AuthorizedCallers.UnauthorizedCaller.selector, s_adminCaller));

    s_handler.deposit(address(s_token), BRIDGE_CHAIN_SELECTOR, amount);
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
    vm.expectRevert(ERC20LockBoxTokenHandler.TokenAmountCannotBeZero.selector);

    s_handler.deposit(address(s_token), BRIDGE_CHAIN_SELECTOR, 0);
    vm.stopPrank();
  }

  function test_deposit_RevertWhen_UnsupportedToken() public {
    uint256 amount = 1_000e18;
    CrossChainToken unsupportedToken = new CrossChainToken(
      BaseERC20.ConstructorParams({
        name: "BAD",
        symbol: "BAD",
        decimals: 18,
        maxSupply: 0,
        preMint: 0,
        preMintRecipient: address(0),
        ccipAdmin: OWNER
      }),
      OWNER,
      OWNER
    );

    vm.startPrank(s_bridgeCaller);
    deal(address(unsupportedToken), s_bridgeCaller, amount);
    unsupportedToken.approve(address(s_handler), amount);
    vm.expectRevert(
      abi.encodeWithSelector(ERC20LockBoxTokenHandler.UnsupportedToken.selector, address(unsupportedToken))
    );

    s_handler.deposit(address(unsupportedToken), BRIDGE_CHAIN_SELECTOR, amount);
    vm.stopPrank();
  }
}
