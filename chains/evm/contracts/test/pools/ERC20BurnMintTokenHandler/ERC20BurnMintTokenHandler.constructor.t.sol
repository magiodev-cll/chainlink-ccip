// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ERC20BurnMintTokenHandler} from "../../../pools/ERC20BurnMintTokenHandler.sol";

import {AuthorizedCallers} from "@chainlink/contracts/src/v0.8/shared/access/AuthorizedCallers.sol";
import {Test} from "forge-std/Test.sol";

contract ERC20BurnMintTokenHandler_constructor is Test {
  function test_constructor() public {
    address token = makeAddr("TOKEN");
    ERC20BurnMintTokenHandler handler = new ERC20BurnMintTokenHandler(token);

    assertTrue(handler.isTokenSupported(token));
    assertEq(address(handler.getToken()), token);
  }

  function test_constructor_RevertWhen_TokenIsZeroAddress() public {
    vm.expectRevert(AuthorizedCallers.ZeroAddressNotAllowed.selector);
    new ERC20BurnMintTokenHandler(address(0));
  }
}
