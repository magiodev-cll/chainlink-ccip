// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {SiloedTokenPool} from "../../../pools/SiloedTokenPool.sol";
import {SiloedTokenPoolSetup} from "./SiloedTokenPoolSetup.t.sol";

contract SiloedTokenPool_getTokenHandler is SiloedTokenPoolSetup {
  function test_getTokenHandler() public view {
    assertEq(address(s_siloedTokenPool.getTokenHandler(DEST_CHAIN_SELECTOR)), address(s_tokenHandler));
    assertEq(address(s_siloedTokenPool.getTokenHandler(SILOED_CHAIN_SELECTOR)), address(s_siloTokenHandler));
  }

  function test_getTokenHandler_RevertWhen_TokenHandlerNotConfigured() public {
    uint64 unconfiguredChainSelector = 999;
    vm.expectRevert(
      abi.encodeWithSelector(SiloedTokenPool.TokenHandlerNotConfigured.selector, unconfiguredChainSelector)
    );
    s_siloedTokenPool.getTokenHandler(unconfiguredChainSelector);
  }
}
