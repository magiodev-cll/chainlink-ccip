// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Pool} from "../../../libraries/Pool.sol";
import {SiloedTokenPoolSetup} from "./SiloedTokenPoolSetup.t.sol";

import {IERC20} from "@openzeppelin/contracts@5.3.0/token/ERC20/IERC20.sol";

contract SiloedTokenPool_releaseOrMint is SiloedTokenPoolSetup {
  function setUp() public override {
    super.setUp();

    s_token.approve(address(s_tokenHandler), type(uint256).max);
    s_token.approve(address(s_siloTokenHandler), type(uint256).max);
  }

  function test_ReleaseOrMint_SiloedChain() public {
    uint256 amount = 10e18;

    deal(address(s_token), address(s_siloedTokenPool), amount);

    vm.startPrank(s_allowedOnRamp);

    // Lock funds so that they can be released without underflowing the internal accounting.
    s_siloedTokenPool.lockOrBurn(
      Pool.LockOrBurnInV1({
        originalSender: STRANGER,
        receiver: bytes(""),
        amount: amount,
        remoteChainSelector: SILOED_CHAIN_SELECTOR,
        localToken: address(s_token)
      })
    );

    assertEq(s_token.balanceOf(address(s_siloTokenHandler)), amount);

    vm.startPrank(s_allowedOffRamp);

    vm.expectEmit();
    emit IERC20.Transfer(address(s_siloTokenHandler), OWNER, amount);

    s_siloedTokenPool.releaseOrMint(
      Pool.ReleaseOrMintInV1({
        originalSender: bytes(""),
        receiver: OWNER,
        sourceDenominatedAmount: amount,
        localToken: address(s_token),
        remoteChainSelector: SILOED_CHAIN_SELECTOR,
        sourcePoolAddress: abi.encode(s_siloedDestPoolAddress),
        sourcePoolData: "",
        offchainTokenData: ""
      })
    );

    assertEq(s_token.balanceOf(address(s_siloTokenHandler)), 0);
  }

  function test_ReleaseOrMint_UnsiloedChain() public {
    uint256 amount = 10e18;

    deal(address(s_token), address(s_siloedTokenPool), amount);
    vm.startPrank(s_allowedOnRamp);

    // Lock funds so they can be released later.
    s_siloedTokenPool.lockOrBurn(
      Pool.LockOrBurnInV1({
        originalSender: STRANGER,
        receiver: bytes(""),
        amount: amount,
        remoteChainSelector: SOURCE_CHAIN_SELECTOR,
        localToken: address(s_token)
      })
    );

    assertEq(s_token.balanceOf(address(s_tokenHandler)), amount);

    vm.startPrank(s_allowedOffRamp);

    vm.expectEmit();
    emit IERC20.Transfer(address(s_tokenHandler), OWNER, amount);

    s_siloedTokenPool.releaseOrMint(
      Pool.ReleaseOrMintInV1({
        originalSender: bytes(""),
        receiver: OWNER,
        sourceDenominatedAmount: amount,
        localToken: address(s_token),
        remoteChainSelector: SOURCE_CHAIN_SELECTOR,
        sourcePoolAddress: abi.encode(s_siloedDestPoolAddress),
        sourcePoolData: "",
        offchainTokenData: ""
      })
    );

    assertEq(s_token.balanceOf(address(s_tokenHandler)), 0);
  }

  function test_ReleaseOrMintV2_SiloedChain() public {
    uint256 amount = 10e18;
    address recipient = makeAddr("recipient");

    deal(address(s_token), address(s_siloedTokenPool), amount);

    vm.startPrank(s_allowedOnRamp);

    s_siloedTokenPool.lockOrBurn(
      Pool.LockOrBurnInV1({
        originalSender: STRANGER,
        receiver: bytes(""),
        amount: amount,
        remoteChainSelector: SILOED_CHAIN_SELECTOR,
        localToken: address(s_token)
      })
    );

    vm.startPrank(s_allowedOffRamp);

    Pool.ReleaseOrMintOutV1 memory output = s_siloedTokenPool.releaseOrMint(
      Pool.ReleaseOrMintInV1({
        originalSender: bytes(""),
        receiver: recipient,
        sourceDenominatedAmount: amount,
        localToken: address(s_token),
        remoteChainSelector: SILOED_CHAIN_SELECTOR,
        sourcePoolAddress: abi.encode(s_siloedDestPoolAddress),
        sourcePoolData: "",
        offchainTokenData: ""
      }),
      0
    );

    assertEq(output.destinationAmount, amount);
    assertEq(s_token.balanceOf(recipient), amount);
    assertEq(s_token.balanceOf(address(s_siloTokenHandler)), 0);
  }
}
