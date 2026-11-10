// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ERC20BurnMintTokenHandler} from "../../../pools/ERC20BurnMintTokenHandler.sol";
import {SiloedTokenPool} from "../../../pools/SiloedTokenPool.sol";
import {TokenPool} from "../../../pools/TokenPool.sol";
import {BaseERC20} from "../../../tokens/BaseERC20.sol";
import {CrossChainToken} from "../../../tokens/CrossChainToken.sol";
import {BaseTest} from "../../BaseTest.t.sol";
import {AuthorizedCallers} from "@chainlink/contracts/src/v0.8/shared/access/AuthorizedCallers.sol";

import {Pool} from "../../../libraries/Pool.sol";

import {IERC20} from "@openzeppelin/contracts@5.3.0/token/ERC20/IERC20.sol";

contract SiloedTokenPool_burnMint is BaseTest {
  uint64 internal constant REMOTE_CHAIN_SELECTOR = DEST_CHAIN_SELECTOR;

  address internal constant ON_RAMP = address(123);
  address internal constant OFF_RAMP = address(234);
  address internal constant REMOTE_POOL = address(999);

  CrossChainToken internal s_token;
  ERC20BurnMintTokenHandler internal s_handler;
  SiloedTokenPool internal s_pool;

  function setUp() public override {
    super.setUp();

    s_token = new CrossChainToken(
      BaseERC20.ConstructorParams({
        name: "TKN", symbol: "T", decimals: 18, maxSupply: 0, preMint: 0, preMintRecipient: address(0), ccipAdmin: OWNER
      }),
      OWNER,
      OWNER
    );
    s_token.grantMintAndBurnRoles(OWNER);

    s_handler = new ERC20BurnMintTokenHandler(address(s_token));
    s_token.grantMintAndBurnRoles(address(s_handler));
    s_handler.setSelectorAllowed(REMOTE_CHAIN_SELECTOR, true);

    s_pool = new SiloedTokenPool(
      IERC20(address(s_token)), DEFAULT_TOKEN_DECIMALS, address(0), address(s_mockRMNRemote), address(s_sourceRouter)
    );

    address[] memory callers = new address[](1);
    callers[0] = address(s_pool);
    s_handler.applyAuthorizedCallerUpdates(
      AuthorizedCallers.AuthorizedCallerArgs({addedCallers: callers, removedCallers: new address[](0)})
    );

    SiloedTokenPool.TokenHandlerConfig[] memory tokenHandlers = new SiloedTokenPool.TokenHandlerConfig[](1);
    tokenHandlers[0] = SiloedTokenPool.TokenHandlerConfig({
      remoteChainSelector: REMOTE_CHAIN_SELECTOR, tokenHandler: address(s_handler)
    });
    s_pool.configureTokenHandlers(tokenHandlers);

    bytes[] memory remotePoolAddresses = new bytes[](1);
    remotePoolAddresses[0] = abi.encode(REMOTE_POOL);

    TokenPool.ChainUpdate[] memory chainUpdates = new TokenPool.ChainUpdate[](1);
    chainUpdates[0] = TokenPool.ChainUpdate({
      remoteChainSelector: REMOTE_CHAIN_SELECTOR,
      remotePoolAddresses: remotePoolAddresses,
      remoteTokenAddress: abi.encode(address(2)),
      outboundRateLimiterConfig: _getOutboundRateLimiterConfig(),
      inboundRateLimiterConfig: _getInboundRateLimiterConfig()
    });
    s_pool.applyChainUpdates(new uint64[](0), chainUpdates);

    _setMockRouterOnRamp(address(s_sourceRouter), REMOTE_CHAIN_SELECTOR, ON_RAMP);
    _setMockRouterOffRamp(address(s_sourceRouter), REMOTE_CHAIN_SELECTOR, OFF_RAMP, true);
  }

  function test_lockOrBurn_BurnsThroughHandler() public {
    uint256 amount = 100e18;
    s_token.mint(address(s_pool), amount);
    uint256 supplyBefore = s_token.totalSupply();

    vm.startPrank(ON_RAMP);
    s_pool.lockOrBurn(
      Pool.LockOrBurnInV1({
        originalSender: STRANGER,
        receiver: bytes(""),
        amount: amount,
        remoteChainSelector: REMOTE_CHAIN_SELECTOR,
        localToken: address(s_token)
      })
    );
    vm.stopPrank();

    assertEq(s_token.totalSupply(), supplyBefore - amount);
    assertEq(s_token.balanceOf(address(s_pool)), 0);
    assertEq(s_token.balanceOf(address(s_handler)), 0);
  }

  function test_releaseOrMint_MintsThroughHandler() public {
    uint256 amount = 100e18;
    address recipient = makeAddr("recipient");
    uint256 supplyBefore = s_token.totalSupply();

    vm.startPrank(OFF_RAMP);
    s_pool.releaseOrMint(
      Pool.ReleaseOrMintInV1({
        originalSender: bytes(""),
        receiver: recipient,
        sourceDenominatedAmount: amount,
        localToken: address(s_token),
        remoteChainSelector: REMOTE_CHAIN_SELECTOR,
        sourcePoolAddress: abi.encode(REMOTE_POOL),
        sourcePoolData: "",
        offchainTokenData: ""
      })
    );
    vm.stopPrank();

    assertEq(s_token.balanceOf(recipient), amount);
    assertEq(s_token.totalSupply(), supplyBefore + amount);
  }
}
