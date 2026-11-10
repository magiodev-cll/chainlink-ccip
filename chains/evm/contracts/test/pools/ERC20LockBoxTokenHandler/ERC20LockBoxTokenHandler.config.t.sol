// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ITokenHandler} from "../../../interfaces/ITokenHandler.sol";
import {ERC20LockBoxTokenHandler} from "../../../pools/ERC20LockBoxTokenHandler.sol";
import {TokenHandler} from "../../../pools/TokenHandler.sol";
import {ERC20LockBoxTokenHandlerSetup} from "./ERC20LockBoxTokenHandlerSetup.t.sol";
import {AuthorizedCallers} from "@chainlink/contracts/src/v0.8/shared/access/AuthorizedCallers.sol";
import {IERC165} from "@openzeppelin/contracts@5.3.0/utils/introspection/IERC165.sol";

contract ERC20LockBoxTokenHandler_config is ERC20LockBoxTokenHandlerSetup {
  function test_supportsInterface() public view {
    assertTrue(s_handler.supportsInterface(type(ITokenHandler).interfaceId));
    assertTrue(s_handler.supportsInterface(type(IERC165).interfaceId));
    assertFalse(s_handler.supportsInterface(0xffffffff));
  }

  function test_getMechanism() public view {
    assertTrue(s_handler.getMechanism() == ITokenHandler.Mechanism.LOCK_RELEASE);
  }

  function test_setSelectorAllowed() public {
    vm.expectEmit();
    emit TokenHandler.SelectorAllowedSet(OTHER_CHAIN_SELECTOR, true);
    s_handler.setSelectorAllowed(OTHER_CHAIN_SELECTOR, true);

    assertTrue(s_handler.isSelectorAllowed(OTHER_CHAIN_SELECTOR));

    vm.expectEmit();
    emit TokenHandler.SelectorAllowedSet(OTHER_CHAIN_SELECTOR, false);
    s_handler.setSelectorAllowed(OTHER_CHAIN_SELECTOR, false);

    assertFalse(s_handler.isSelectorAllowed(OTHER_CHAIN_SELECTOR));
  }

  function test_setSelectorAllowed_RevertWhen_ZeroSelector() public {
    vm.expectRevert(TokenHandler.InvalidChainSelector.selector);
    s_handler.setSelectorAllowed(0, true);
  }

  function test_setAdminCaller() public {
    vm.expectEmit();
    emit TokenHandler.AdminCallerSet(s_adminCaller, false);
    s_handler.setAdminCaller(s_adminCaller, false);

    assertFalse(s_handler.isAdminCaller(s_adminCaller));

    vm.expectEmit();
    emit TokenHandler.AdminCallerSet(s_adminCaller, true);
    s_handler.setAdminCaller(s_adminCaller, true);

    assertTrue(s_handler.isAdminCaller(s_adminCaller));
  }

  function test_setAdminCaller_RevertWhen_ZeroAddress() public {
    vm.expectRevert(AuthorizedCallers.ZeroAddressNotAllowed.selector);
    s_handler.setAdminCaller(address(0), true);
  }
}
