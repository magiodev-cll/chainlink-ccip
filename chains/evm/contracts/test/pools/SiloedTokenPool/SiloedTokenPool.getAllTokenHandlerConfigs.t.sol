// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ERC20LockReleaseTokenHandler} from "../../../pools/ERC20LockReleaseTokenHandler.sol";
import {SiloedTokenPool} from "../../../pools/SiloedTokenPool.sol";
import {BaseERC20} from "../../../tokens/BaseERC20.sol";
import {CrossChainToken} from "../../../tokens/CrossChainToken.sol";
import {BaseTest} from "../../BaseTest.t.sol";

import {IERC20} from "@openzeppelin/contracts@5.3.0/token/ERC20/IERC20.sol";

contract SiloedTokenPool_getAllTokenHandlerConfigs is BaseTest {
  uint64 internal constant CHAIN_A = 1;
  uint64 internal constant CHAIN_B = 2;
  uint64 internal constant CHAIN_C = 3;

  IERC20 internal s_token;
  SiloedTokenPool internal s_pool;
  ERC20LockReleaseTokenHandler internal s_sharedTokenHandler;
  ERC20LockReleaseTokenHandler internal s_isolatedTokenHandler;

  function setUp() public override {
    super.setUp();

    s_token = IERC20(
      address(
        new CrossChainToken(
          BaseERC20.ConstructorParams({
            name: "TEST",
            symbol: "TST",
            decimals: 18,
            maxSupply: 0,
            preMint: 0,
            preMintRecipient: address(0),
            ccipAdmin: OWNER
          }),
          OWNER,
          OWNER
        )
      )
    );

    s_pool = new SiloedTokenPool(
      s_token, DEFAULT_TOKEN_DECIMALS, address(0), address(s_mockRMNRemote), address(s_sourceRouter)
    );

    s_sharedTokenHandler = new ERC20LockReleaseTokenHandler(address(s_token));
    s_isolatedTokenHandler = new ERC20LockReleaseTokenHandler(address(s_token));
    s_sharedTokenHandler.setSelectorAllowed(CHAIN_A, true);
    s_sharedTokenHandler.setSelectorAllowed(CHAIN_B, true);
    s_isolatedTokenHandler.setSelectorAllowed(CHAIN_C, true);

    // Setup router.
    _setMockRouterOnRamp(address(s_sourceRouter), CHAIN_A, address(1));
    _setMockRouterOnRamp(address(s_sourceRouter), CHAIN_B, address(2));
    _setMockRouterOnRamp(address(s_sourceRouter), CHAIN_C, address(3));
  }

  function test_getAllTokenHandlerConfigs() public {
    // - CHAIN_A: shared token handler.
    // - CHAIN_B: shared token handler (same as CHAIN_A).
    // - CHAIN_C: isolated token handler.
    SiloedTokenPool.TokenHandlerConfig[] memory tokenHandlers = new SiloedTokenPool.TokenHandlerConfig[](3);
    tokenHandlers[0] =
      SiloedTokenPool.TokenHandlerConfig({remoteChainSelector: CHAIN_A, tokenHandler: address(s_sharedTokenHandler)});
    tokenHandlers[1] =
      SiloedTokenPool.TokenHandlerConfig({remoteChainSelector: CHAIN_B, tokenHandler: address(s_sharedTokenHandler)});
    tokenHandlers[2] =
      SiloedTokenPool.TokenHandlerConfig({remoteChainSelector: CHAIN_C, tokenHandler: address(s_isolatedTokenHandler)});
    s_pool.configureTokenHandlers(tokenHandlers);

    SiloedTokenPool.TokenHandlerConfig[] memory configs = s_pool.getAllTokenHandlerConfigs();

    assertEq(configs.length, 3);
    assertEq(configs[0].remoteChainSelector, CHAIN_A);
    assertEq(configs[0].tokenHandler, address(s_sharedTokenHandler));
    assertEq(configs[1].remoteChainSelector, CHAIN_B);
    assertEq(configs[1].tokenHandler, address(s_sharedTokenHandler));
    assertEq(configs[2].remoteChainSelector, CHAIN_C);
    assertEq(configs[2].tokenHandler, address(s_isolatedTokenHandler));
  }
}
