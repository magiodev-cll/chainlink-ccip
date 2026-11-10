// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ERC20LockBoxTokenHandler} from "../../../../pools/ERC20LockBoxTokenHandler.sol";
import {SiloedTokenPool} from "../../../../pools/SiloedTokenPool.sol";
import {SiloedUSDCTokenPool} from "../../../../pools/USDC/SiloedUSDCTokenPool.sol";
import {SiloedUSDCTokenPoolSetup} from "./SiloedUSDCTokenPoolSetup.t.sol";
import {AuthorizedCallers} from "@chainlink/contracts/src/v0.8/shared/access/AuthorizedCallers.sol";

contract SiloedUSDCTokenPool_configureTokenHandlers is SiloedUSDCTokenPoolSetup {
  function test_configureTokenHandlers() public {
    ERC20LockBoxTokenHandler newSourceTokenHandler = new ERC20LockBoxTokenHandler(address(s_USDCToken));
    ERC20LockBoxTokenHandler newDestTokenHandler = new ERC20LockBoxTokenHandler(address(s_USDCToken));

    newSourceTokenHandler.setSelectorAllowed(SOURCE_CHAIN_SELECTOR, true);
    newDestTokenHandler.setSelectorAllowed(DEST_CHAIN_SELECTOR, true);

    address[] memory allowedCallers = new address[](1);
    allowedCallers[0] = address(s_usdcTokenPool);

    newSourceTokenHandler.applyAuthorizedCallerUpdates(
      AuthorizedCallers.AuthorizedCallerArgs({addedCallers: allowedCallers, removedCallers: new address[](0)})
    );
    newDestTokenHandler.applyAuthorizedCallerUpdates(
      AuthorizedCallers.AuthorizedCallerArgs({addedCallers: allowedCallers, removedCallers: new address[](0)})
    );

    SiloedTokenPool.TokenHandlerConfig[] memory tokenHandlers = new SiloedTokenPool.TokenHandlerConfig[](2);
    tokenHandlers[0] = SiloedTokenPool.TokenHandlerConfig({
      remoteChainSelector: SOURCE_CHAIN_SELECTOR, tokenHandler: address(newSourceTokenHandler)
    });
    tokenHandlers[1] = SiloedTokenPool.TokenHandlerConfig({
      remoteChainSelector: DEST_CHAIN_SELECTOR, tokenHandler: address(newDestTokenHandler)
    });

    s_usdcTokenPool.configureTokenHandlers(tokenHandlers);

    assertEq(address(s_usdcTokenPool.getTokenHandler(SOURCE_CHAIN_SELECTOR)), address(newSourceTokenHandler));
    assertEq(address(s_usdcTokenPool.getTokenHandler(DEST_CHAIN_SELECTOR)), address(newDestTokenHandler));
  }

  function test_configureTokenHandlers_RevertWhen_TokenHandlerCannotBeShared() public {
    s_sourceTokenHandler.setSelectorAllowed(DEST_CHAIN_SELECTOR, true);

    SiloedTokenPool.TokenHandlerConfig[] memory tokenHandlers = new SiloedTokenPool.TokenHandlerConfig[](2);
    tokenHandlers[0] = SiloedTokenPool.TokenHandlerConfig({
      remoteChainSelector: SOURCE_CHAIN_SELECTOR, tokenHandler: address(s_sourceTokenHandler)
    });
    tokenHandlers[1] = SiloedTokenPool.TokenHandlerConfig({
      remoteChainSelector: DEST_CHAIN_SELECTOR, tokenHandler: address(s_sourceTokenHandler)
    });

    vm.expectRevert(
      abi.encodeWithSelector(
        SiloedUSDCTokenPool.TokenHandlerCannotBeShared.selector,
        SOURCE_CHAIN_SELECTOR,
        DEST_CHAIN_SELECTOR,
        address(s_sourceTokenHandler)
      )
    );
    s_usdcTokenPool.configureTokenHandlers(tokenHandlers);
  }
}
