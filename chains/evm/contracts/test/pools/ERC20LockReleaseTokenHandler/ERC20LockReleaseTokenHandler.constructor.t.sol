// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ERC20LockReleaseTokenHandler} from "../../../pools/ERC20LockReleaseTokenHandler.sol";

import {AuthorizedCallers} from "@chainlink/contracts/src/v0.8/shared/access/AuthorizedCallers.sol";
import {Test} from "forge-std/Test.sol";

contract ERC20LockReleaseTokenHandler_constructor is Test {
  function test_constructor() public {
    address token = makeAddr("TOKEN");
    ERC20LockReleaseTokenHandler handler = new ERC20LockReleaseTokenHandler(token);

    assertTrue(handler.isTokenSupported(token));
    assertEq(address(handler.getToken()), token);
  }

  function test_constructor_RevertWhen_TokenIsZeroAddress() public {
    vm.expectRevert(AuthorizedCallers.ZeroAddressNotAllowed.selector);
    new ERC20LockReleaseTokenHandler(address(0));
  }
}
