// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ITokenHandler} from "../../../interfaces/ITokenHandler.sol";
import {ExternalMinterTokenHandler} from "../../../pools/ExternalMinterTokenHandler.sol";
import {BaseERC20} from "../../../tokens/BaseERC20.sol";
import {CrossChainToken} from "../../../tokens/CrossChainToken.sol";
import {ExternalMinterTokenHandlerSetup} from "./ExternalMinterTokenHandlerSetup.t.sol";

contract ExternalMinterTokenHandler_config is ExternalMinterTokenHandlerSetup {
  function test_constructor() public view {
    assertEq(address(s_handler.getToken()), address(s_token));
    assertEq(address(s_handler.getMinter()), address(s_minter));
    assertEq(s_handler.typeAndVersion(), "ExternalMinterTokenHandler 2.1.0");
    assertTrue(s_handler.getMechanism() == ITokenHandler.Mechanism.BURN_MINT);
  }

  function test_constructor_RevertWhen_MinterTokenMismatch() public {
    CrossChainToken otherToken = new CrossChainToken(
      BaseERC20.ConstructorParams({
        name: "OTHER",
        symbol: "OTH",
        decimals: 18,
        maxSupply: 0,
        preMint: 0,
        preMintRecipient: address(0),
        ccipAdmin: OWNER
      }),
      OWNER,
      OWNER
    );

    vm.expectRevert(
      abi.encodeWithSelector(
        ExternalMinterTokenHandler.MinterTokenMismatch.selector, address(otherToken), address(s_token)
      )
    );
    new ExternalMinterTokenHandler(address(otherToken), address(s_minter));
  }

  function test_constructor_RevertWhen_ZeroMinter() public {
    vm.expectRevert();
    new ExternalMinterTokenHandler(address(s_token), address(0));
  }

  function test_supportsInterface() public view {
    assertTrue(s_handler.supportsInterface(type(ITokenHandler).interfaceId));
  }
}
