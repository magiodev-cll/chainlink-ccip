// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ITokenHandler} from "../../../interfaces/ITokenHandler.sol";
import {ERC20BurnMintTokenHandler} from "../../../pools/ERC20BurnMintTokenHandler.sol";
import {ERC20BurnMintTokenHandlerSetup} from "./ERC20BurnMintTokenHandlerSetup.t.sol";
import {IERC165} from "@openzeppelin/contracts@5.3.0/utils/introspection/IERC165.sol";

contract ERC20BurnMintTokenHandler_config is ERC20BurnMintTokenHandlerSetup {
  function test_supportsInterface() public view {
    assertTrue(s_handler.supportsInterface(type(ITokenHandler).interfaceId));
    assertTrue(s_handler.supportsInterface(type(IERC165).interfaceId));
    assertFalse(s_handler.supportsInterface(0xffffffff));
  }

  function test_getMechanism() public view {
    assertTrue(s_handler.getMechanism() == ITokenHandler.Mechanism.BURN_MINT);
  }

  function test_typeAndVersion() public view {
    assertEq(s_handler.typeAndVersion(), "ERC20BurnMintTokenHandler 2.0.0");
  }

  function test_getToken() public view {
    assertEq(address(s_handler.getToken()), address(s_token));
  }
}
