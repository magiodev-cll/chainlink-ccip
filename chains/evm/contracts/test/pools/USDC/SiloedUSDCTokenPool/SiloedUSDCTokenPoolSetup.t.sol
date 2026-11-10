// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ERC20LockReleaseTokenHandler} from "../../../../pools/ERC20LockReleaseTokenHandler.sol";
import {SiloedTokenPool} from "../../../../pools/SiloedTokenPool.sol";
import {SiloedUSDCTokenPool} from "../../../../pools/USDC/SiloedUSDCTokenPool.sol";
import {CrossChainToken} from "../../../../tokens/CrossChainToken.sol";
import {USDCSetup} from "../USDCSetup.t.sol";
import {AuthorizedCallers} from "@chainlink/contracts/src/v0.8/shared/access/AuthorizedCallers.sol";

contract SiloedUSDCTokenPoolSetup is USDCSetup {
  SiloedUSDCTokenPool internal s_usdcTokenPool;
  SiloedUSDCTokenPool internal s_usdcTokenPoolTransferLiquidity;

  ERC20LockReleaseTokenHandler internal s_sourceTokenHandler;
  ERC20LockReleaseTokenHandler internal s_destTokenHandler;

  function setUp() public virtual override {
    super.setUp();

    s_sourceTokenHandler = new ERC20LockReleaseTokenHandler(address(s_USDCToken));
    s_destTokenHandler = new ERC20LockReleaseTokenHandler(address(s_USDCToken));

    s_usdcTokenPool = new SiloedUSDCTokenPool(
      s_USDCToken,
      6, // localTokenDecimals
      address(0), // allowlist
      address(s_mockRMNRemote), // rmnProxy
      address(s_router) // router
    );

    address[] memory authorizedCallers = new address[](3);
    authorizedCallers[0] = OWNER;
    authorizedCallers[1] = address(s_routerAllowedOnRamp);
    authorizedCallers[2] = address(s_routerAllowedOffRamp);
    s_usdcTokenPool.applyAuthorizedCallerUpdates(
      AuthorizedCallers.AuthorizedCallerArgs({addedCallers: authorizedCallers, removedCallers: new address[](0)})
    );

    CrossChainToken(address(s_USDCToken)).grantMintAndBurnRoles(address(s_usdcTokenPool));

    s_tokenAdminRegistry.proposeAdministrator(address(s_USDCToken), OWNER);
    s_tokenAdminRegistry.acceptAdminRole(address(s_USDCToken));
    s_tokenAdminRegistry.setPool(address(s_USDCToken), address(s_usdcTokenPool));

    _poolApplyChainUpdates(address(s_usdcTokenPool));

    // Mock the getPool function to return the address of the token pool
    vm.mockCall(
      address(s_tokenAdminRegistry),
      abi.encodeWithSignature("getPool(address)", address(s_USDCToken)),
      abi.encode(address(s_usdcTokenPool))
    );

    // Allow the router to call the releaseOrMint function
    s_usdcTokenPoolTransferLiquidity = new SiloedUSDCTokenPool(
      s_USDCToken,
      6, // localTokenDecimals
      address(0), // allowlist
      address(s_mockRMNRemote), // rmnProxy
      address(s_router) // router
    );

    s_usdcTokenPoolTransferLiquidity.applyAuthorizedCallerUpdates(
      AuthorizedCallers.AuthorizedCallerArgs({addedCallers: authorizedCallers, removedCallers: new address[](0)})
    );

    _poolApplyChainUpdates(address(s_usdcTokenPoolTransferLiquidity));

    // Allow both pools to interact with the token handlers.
    address[] memory allowedCallers = new address[](2);
    allowedCallers[0] = address(s_usdcTokenPool);
    allowedCallers[1] = address(s_usdcTokenPoolTransferLiquidity);

    s_sourceTokenHandler.setSelectorAllowed(SOURCE_CHAIN_SELECTOR, true);
    s_destTokenHandler.setSelectorAllowed(DEST_CHAIN_SELECTOR, true);

    s_sourceTokenHandler.applyAuthorizedCallerUpdates(
      AuthorizedCallers.AuthorizedCallerArgs({addedCallers: allowedCallers, removedCallers: new address[](0)})
    );
    s_destTokenHandler.applyAuthorizedCallerUpdates(
      AuthorizedCallers.AuthorizedCallerArgs({addedCallers: allowedCallers, removedCallers: new address[](0)})
    );

    SiloedTokenPool.TokenHandlerConfig[] memory tokenHandlers = new SiloedTokenPool.TokenHandlerConfig[](2);
    tokenHandlers[0] = SiloedTokenPool.TokenHandlerConfig({
      remoteChainSelector: SOURCE_CHAIN_SELECTOR, tokenHandler: address(s_sourceTokenHandler)
    });
    tokenHandlers[1] = SiloedTokenPool.TokenHandlerConfig({
      remoteChainSelector: DEST_CHAIN_SELECTOR, tokenHandler: address(s_destTokenHandler)
    });
    s_usdcTokenPool.configureTokenHandlers(tokenHandlers);
    s_usdcTokenPoolTransferLiquidity.configureTokenHandlers(tokenHandlers);
  }
}
