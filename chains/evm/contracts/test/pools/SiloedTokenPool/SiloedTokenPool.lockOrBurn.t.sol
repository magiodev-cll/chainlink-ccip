// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IPoolV2} from "../../../interfaces/IPoolV2.sol";
import {ITokenHandler} from "../../../interfaces/ITokenHandler.sol";

import {Pool} from "../../../libraries/Pool.sol";
import {SiloedTokenPool} from "../../../pools/SiloedTokenPool.sol";
import {TokenPool} from "../../../pools/TokenPool.sol";
import {SiloedTokenPoolSetup} from "./SiloedTokenPoolSetup.t.sol";

import {IERC20} from "@openzeppelin/contracts@5.3.0/token/ERC20/IERC20.sol";

/// @notice Mock token handler that intentionally leaves dangling allowance for testing.
contract MockTokenHandlerWithDanglingAllowance is ITokenHandler {
  IERC20 internal immutable i_token;

  constructor(
    address token
  ) {
    i_token = IERC20(token);
  }

  function deposit(
    address,
    uint64,
    uint256 amount
  ) external {
    // Only transfer half the amount, leaving dangling allowance.
    i_token.transferFrom(msg.sender, address(this), amount / 2);
  }

  function withdraw(
    address,
    uint64,
    uint256,
    address
  ) external {}

  function isTokenSupported(
    address token
  ) external view returns (bool) {
    return token == address(i_token);
  }

  function isSelectorAllowed(
    uint64
  ) external pure returns (bool) {
    return true;
  }

  function getMechanism() external pure returns (Mechanism) {
    return Mechanism.LOCK_RELEASE;
  }
}

contract SiloedTokenPool_lockOrBurn is SiloedTokenPoolSetup {
  uint256 public constant AMOUNT = 10e18;

  function test_lockOrBurn_SiloedFunds() public {
    deal(address(s_token), address(s_siloedTokenPool), AMOUNT);

    vm.startPrank(s_allowedOnRamp);

    vm.expectEmit();
    emit TokenPool.OutboundRateLimitConsumed({
      remoteChainSelector: SILOED_CHAIN_SELECTOR, token: address(s_token), amount: AMOUNT
    });

    vm.expectEmit();
    emit TokenPool.LockedOrBurned({
      remoteChainSelector: SILOED_CHAIN_SELECTOR,
      token: address(s_token),
      sender: address(s_allowedOnRamp),
      amount: AMOUNT
    });

    s_siloedTokenPool.lockOrBurn(
      Pool.LockOrBurnInV1({
        originalSender: STRANGER,
        receiver: bytes(""),
        amount: AMOUNT,
        remoteChainSelector: SILOED_CHAIN_SELECTOR,
        localToken: address(s_token)
      })
    );

    assertEq(s_token.balanceOf(address(s_siloedTokenPool.getTokenHandler(SILOED_CHAIN_SELECTOR))), AMOUNT);
  }

  function test_lockOrBurn_UnsiloedFunds() public {
    vm.startPrank(s_allowedOnRamp);
    deal(address(s_token), address(s_siloedTokenPool), AMOUNT);

    vm.expectEmit();
    emit TokenPool.OutboundRateLimitConsumed({
      remoteChainSelector: DEST_CHAIN_SELECTOR, token: address(s_token), amount: AMOUNT
    });

    vm.expectEmit();
    emit TokenPool.LockedOrBurned({
      remoteChainSelector: DEST_CHAIN_SELECTOR,
      token: address(s_token),
      sender: address(s_allowedOnRamp),
      amount: AMOUNT
    });

    s_siloedTokenPool.lockOrBurn(
      Pool.LockOrBurnInV1({
        originalSender: STRANGER,
        receiver: bytes(""),
        amount: AMOUNT,
        remoteChainSelector: DEST_CHAIN_SELECTOR,
        localToken: address(s_token)
      })
    );

    assertEq(s_token.balanceOf(address(s_tokenHandler)), AMOUNT);
  }

  function test_lockOrBurnV2_SiloedFundsWithFee() public {
    uint256 amount = 1000e18;
    uint16 defaultFeeBps = 100;
    uint256 expectedFee = (amount * defaultFeeBps) / 10_000;
    uint256 expectedDestAmount = amount - expectedFee;

    IPoolV2.TokenTransferFeeConfig memory feeConfig = IPoolV2.TokenTransferFeeConfig({
      destGasOverhead: 50_000,
      destBytesOverhead: 32,
      finalityFeeUSDCents: 0,
      fastFinalityFeeUSDCents: 0,
      finalityTransferFeeBps: defaultFeeBps,
      fastFinalityTransferFeeBps: 0,
      isEnabled: true
    });

    TokenPool.TokenTransferFeeConfigArgs[] memory feeConfigArgs = new TokenPool.TokenTransferFeeConfigArgs[](1);
    feeConfigArgs[0] = TokenPool.TokenTransferFeeConfigArgs({
      destChainSelector: SILOED_CHAIN_SELECTOR, tokenTransferFeeConfig: feeConfig
    });

    s_siloedTokenPool.applyTokenTransferFeeConfigUpdates(feeConfigArgs, new uint64[](0));

    uint256 tokenHandlerBalanceBefore = s_token.balanceOf(address(s_siloTokenHandler));
    deal(address(s_token), address(s_siloedTokenPool), amount);

    vm.startPrank(s_allowedOnRamp);

    (, uint256 destTokenAmount) = s_siloedTokenPool.lockOrBurn(
      Pool.LockOrBurnInV1({
        originalSender: STRANGER,
        receiver: bytes(""),
        amount: amount,
        remoteChainSelector: SILOED_CHAIN_SELECTOR,
        localToken: address(s_token)
      }),
      0,
      ""
    );

    assertEq(destTokenAmount, expectedDestAmount);
    assertEq(s_token.balanceOf(address(s_siloTokenHandler)), tokenHandlerBalanceBefore + expectedDestAmount);
    assertEq(s_token.balanceOf(address(s_siloedTokenPool)), expectedFee);
  }

  function test_lockOrBurn_ResetsAllowanceAfterDeposit() public {
    // Create a mock token handler that leaves dangling allowance.
    MockTokenHandlerWithDanglingAllowance mockTokenHandler = new MockTokenHandlerWithDanglingAllowance(address(s_token));

    // Configure the mock token handler for a new chain selector.
    uint64 testChainSelector = 99999;
    SiloedTokenPool.TokenHandlerConfig[] memory tokenHandlers = new SiloedTokenPool.TokenHandlerConfig[](1);
    tokenHandlers[0] = SiloedTokenPool.TokenHandlerConfig({
      remoteChainSelector: testChainSelector, tokenHandler: address(mockTokenHandler)
    });
    s_siloedTokenPool.configureTokenHandlers(tokenHandlers);

    // Configure chain for the pool.
    bytes[] memory remotePoolAddresses = new bytes[](1);
    remotePoolAddresses[0] = abi.encode(address(1234));

    TokenPool.ChainUpdate[] memory chainUpdates = new TokenPool.ChainUpdate[](1);
    chainUpdates[0] = TokenPool.ChainUpdate({
      remoteChainSelector: testChainSelector,
      remotePoolAddresses: remotePoolAddresses,
      remoteTokenAddress: abi.encode(address(2)),
      outboundRateLimiterConfig: _getOutboundRateLimiterConfig(),
      inboundRateLimiterConfig: _getInboundRateLimiterConfig()
    });
    s_siloedTokenPool.applyChainUpdates(new uint64[](0), chainUpdates);

    // Add onRamp for the test chain.
    _setMockRouterOnRamp(address(s_sourceRouter), testChainSelector, s_allowedOnRamp);

    // Fund the pool.
    deal(address(s_token), address(s_siloedTokenPool), AMOUNT);

    vm.stopPrank();
    vm.prank(s_allowedOnRamp);
    s_siloedTokenPool.lockOrBurn(
      Pool.LockOrBurnInV1({
        originalSender: STRANGER,
        receiver: bytes(""),
        amount: AMOUNT,
        remoteChainSelector: testChainSelector,
        localToken: address(s_token)
      })
    );

    // Verify the allowance is reset to 0 after the deposit.
    assertEq(s_token.allowance(address(s_siloedTokenPool), address(mockTokenHandler)), 0);
  }
}
