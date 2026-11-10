// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ITokenHandler} from "../../../interfaces/ITokenHandler.sol";
import {BurnMintTokenHandlerBase} from "../../../pools/BurnMintTokenHandlerBase.sol";
import {ERC20BurnMintTokenHandler} from "../../../pools/ERC20BurnMintTokenHandler.sol";
import {TokenHandler} from "../../../pools/TokenHandler.sol";
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

  function test_setSelectorCaps() public {
    vm.expectEmit();
    emit BurnMintTokenHandlerBase.SelectorCapsSet(OTHER_CHAIN_SELECTOR, 100e18, 200e18);

    s_handler.setSelectorCaps(OTHER_CHAIN_SELECTOR, 100e18, 200e18);

    (uint256 minted, uint256 burned, uint256 mintCap, uint256 burnCap) =
      s_handler.getSelectorAccounting(OTHER_CHAIN_SELECTOR);
    assertEq(minted, 0);
    assertEq(burned, 0);
    assertEq(mintCap, 100e18);
    assertEq(burnCap, 200e18);
  }

  function test_setSelectorCaps_RevertWhen_ZeroSelector() public {
    vm.expectRevert(TokenHandler.InvalidChainSelector.selector);
    s_handler.setSelectorCaps(0, 1, 1);
  }

  function test_getSelectorAccounting() public {
    _deposit(s_bridgeCaller, BRIDGE_CHAIN_SELECTOR, 100e18);

    vm.prank(s_bridgeCaller);
    s_handler.withdraw(address(s_token), BRIDGE_CHAIN_SELECTOR, 40e18, s_recipient);

    (uint256 minted, uint256 burned, uint256 mintCap, uint256 burnCap) =
      s_handler.getSelectorAccounting(BRIDGE_CHAIN_SELECTOR);
    assertEq(minted, 40e18);
    assertEq(burned, 100e18);
    assertEq(mintCap, type(uint256).max);
    assertEq(burnCap, type(uint256).max);
  }
}
