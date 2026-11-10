// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ITokenHandler} from "../../../interfaces/ITokenHandler.sol";
import {ERC20ExternalMinterTokenHandler} from "../../../pools/ERC20ExternalMinterTokenHandler.sol";
import {BaseERC20} from "../../../tokens/BaseERC20.sol";
import {CrossChainToken} from "../../../tokens/CrossChainToken.sol";
import {ERC20ExternalMinterTokenHandlerSetup} from "./ERC20ExternalMinterTokenHandlerSetup.t.sol";
import {IERC165} from "@openzeppelin/contracts@5.3.0/utils/introspection/IERC165.sol";

contract ERC20ExternalMinterTokenHandler_config is ERC20ExternalMinterTokenHandlerSetup {
  function test_constructor() public view {
    assertEq(address(s_handler.getToken()), address(s_token));
    assertEq(address(s_handler.getMinter()), address(s_minter));
  }

  function test_getMechanism() public view {
    assertTrue(s_handler.getMechanism() == ITokenHandler.Mechanism.BURN_MINT);
  }

  function test_typeAndVersion() public view {
    assertEq(s_handler.typeAndVersion(), "ERC20ExternalMinterTokenHandler 2.0.0");
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
        ERC20ExternalMinterTokenHandler.MinterTokenMismatch.selector, address(otherToken), address(s_token)
      )
    );
    new ERC20ExternalMinterTokenHandler(address(otherToken), address(s_minter));
  }

  function test_constructor_RevertWhen_ZeroMinter() public {
    vm.expectRevert();
    new ERC20ExternalMinterTokenHandler(address(s_token), address(0));
  }

  function test_supportsInterface() public view {
    assertTrue(s_handler.supportsInterface(type(ITokenHandler).interfaceId));
    assertTrue(s_handler.supportsInterface(type(IERC165).interfaceId));
    assertFalse(s_handler.supportsInterface(0xffffffff));
  }
}
