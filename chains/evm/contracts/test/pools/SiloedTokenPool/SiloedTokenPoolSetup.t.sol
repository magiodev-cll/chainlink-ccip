// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ERC20LockReleaseTokenHandler} from "../../../pools/ERC20LockReleaseTokenHandler.sol";
import {SiloedTokenPool} from "../../../pools/SiloedTokenPool.sol";
import {TokenPool} from "../../../pools/TokenPool.sol";
import {BaseERC20} from "../../../tokens/BaseERC20.sol";
import {CrossChainToken} from "../../../tokens/CrossChainToken.sol";
import {BaseTest} from "../../BaseTest.t.sol";
import {AuthorizedCallers} from "@chainlink/contracts/src/v0.8/shared/access/AuthorizedCallers.sol";

import {IERC20} from "@openzeppelin/contracts@5.3.0/token/ERC20/IERC20.sol";

contract SiloedTokenPoolSetup is BaseTest {
  IERC20 internal s_token;
  SiloedTokenPool internal s_siloedTokenPool;
  address[] internal s_allowedList;

  address internal s_allowedOnRamp = address(123);
  address internal s_allowedOffRamp = address(234);

  address internal s_destPoolAddress = address(2736782345);
  address internal s_sourcePoolAddress = address(53852352095);

  address internal s_siloedDestPoolAddress = address(4245234524);
  uint64 internal constant SILOED_CHAIN_SELECTOR = DEST_CHAIN_SELECTOR + 1;

  ERC20LockReleaseTokenHandler internal s_tokenHandler;
  ERC20LockReleaseTokenHandler internal s_siloTokenHandler;

  function setUp() public virtual override {
    super.setUp();
    s_token = IERC20(
      address(
        new CrossChainToken(
          BaseERC20.ConstructorParams({
            name: "LINK",
            symbol: "LNK",
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
    deal(address(s_token), OWNER, type(uint256).max);

    s_siloedTokenPool = new SiloedTokenPool(
      s_token, DEFAULT_TOKEN_DECIMALS, address(0), address(s_mockRMNRemote), address(s_sourceRouter)
    );

    s_tokenHandler = _deployTokenHandler(DEST_CHAIN_SELECTOR);
    s_siloTokenHandler = _deployTokenHandler(SILOED_CHAIN_SELECTOR);
    s_tokenHandler.setSelectorAllowed(SOURCE_CHAIN_SELECTOR, true);

    // Configure token handlers for both chains.
    SiloedTokenPool.TokenHandlerConfig[] memory tokenHandlers = new SiloedTokenPool.TokenHandlerConfig[](3);
    tokenHandlers[0] = SiloedTokenPool.TokenHandlerConfig({
      remoteChainSelector: DEST_CHAIN_SELECTOR, tokenHandler: address(s_tokenHandler)
    });
    tokenHandlers[1] = SiloedTokenPool.TokenHandlerConfig({
      remoteChainSelector: SILOED_CHAIN_SELECTOR, tokenHandler: address(s_siloTokenHandler)
    });
    tokenHandlers[2] = SiloedTokenPool.TokenHandlerConfig({
      remoteChainSelector: SOURCE_CHAIN_SELECTOR, tokenHandler: address(s_tokenHandler)
    });
    s_siloedTokenPool.configureTokenHandlers(tokenHandlers);

    s_token.approve(address(s_siloedTokenPool), type(uint256).max);

    bytes[] memory remotePoolAddresses = new bytes[](2);
    remotePoolAddresses[0] = abi.encode(s_destPoolAddress);
    remotePoolAddresses[1] = abi.encode(s_siloedDestPoolAddress);

    TokenPool.ChainUpdate[] memory chainUpdates = new TokenPool.ChainUpdate[](3);
    chainUpdates[0] = TokenPool.ChainUpdate({
      remoteChainSelector: DEST_CHAIN_SELECTOR,
      remotePoolAddresses: remotePoolAddresses,
      remoteTokenAddress: abi.encode(address(2)),
      outboundRateLimiterConfig: _getOutboundRateLimiterConfig(),
      inboundRateLimiterConfig: _getInboundRateLimiterConfig()
    });

    chainUpdates[1] = TokenPool.ChainUpdate({
      remoteChainSelector: SILOED_CHAIN_SELECTOR,
      remotePoolAddresses: remotePoolAddresses,
      remoteTokenAddress: abi.encode(address(2)),
      outboundRateLimiterConfig: _getOutboundRateLimiterConfig(),
      inboundRateLimiterConfig: _getInboundRateLimiterConfig()
    });

    chainUpdates[2] = TokenPool.ChainUpdate({
      remoteChainSelector: SOURCE_CHAIN_SELECTOR,
      remotePoolAddresses: remotePoolAddresses,
      remoteTokenAddress: abi.encode(address(2)),
      outboundRateLimiterConfig: _getOutboundRateLimiterConfig(),
      inboundRateLimiterConfig: _getInboundRateLimiterConfig()
    });

    s_siloedTokenPool.applyChainUpdates(new uint64[](0), chainUpdates);

    _setMockRouterOnRamp(address(s_sourceRouter), DEST_CHAIN_SELECTOR, s_allowedOnRamp);
    _setMockRouterOnRamp(address(s_sourceRouter), SILOED_CHAIN_SELECTOR, s_allowedOnRamp);
    _setMockRouterOnRamp(address(s_sourceRouter), SOURCE_CHAIN_SELECTOR, s_allowedOnRamp);

    _setMockRouterOffRamp(address(s_sourceRouter), SOURCE_CHAIN_SELECTOR, s_allowedOffRamp, true);
    _setMockRouterOffRamp(address(s_sourceRouter), SILOED_CHAIN_SELECTOR, s_allowedOffRamp, true);
  }

  function _deployTokenHandler(
    uint64 remoteChainSelector
  ) internal returns (ERC20LockReleaseTokenHandler tokenHandler) {
    tokenHandler = new ERC20LockReleaseTokenHandler(address(s_token));
    tokenHandler.setSelectorAllowed(remoteChainSelector, true);

    address[] memory allowedCallers = new address[](1);
    allowedCallers[0] = address(s_siloedTokenPool);
    tokenHandler.applyAuthorizedCallerUpdates(
      AuthorizedCallers.AuthorizedCallerArgs({addedCallers: allowedCallers, removedCallers: new address[](0)})
    );
  }
}
