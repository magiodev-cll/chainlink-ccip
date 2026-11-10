// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {BurnMintTokenHandler} from "../../../pools/BurnMintTokenHandler.sol";
import {BaseERC20} from "../../../tokens/BaseERC20.sol";
import {CrossChainToken} from "../../../tokens/CrossChainToken.sol";
import {BaseTest} from "../../BaseTest.t.sol";
import {AuthorizedCallers} from "@chainlink/contracts/src/v0.8/shared/access/AuthorizedCallers.sol";

contract BurnMintTokenHandlerSetup is BaseTest {
  CrossChainToken internal s_token;
  BurnMintTokenHandler internal s_handler;
  address internal s_bridgeCaller = makeAddr("bridge_caller");
  address internal s_adminCaller = makeAddr("admin_caller");
  address internal s_recipient = makeAddr("recipient");

  uint64 internal constant BRIDGE_CHAIN_SELECTOR = DEST_CHAIN_SELECTOR;
  uint64 internal constant OTHER_CHAIN_SELECTOR = SOURCE_CHAIN_SELECTOR;

  function setUp() public virtual override {
    super.setUp();
    s_token = new CrossChainToken(
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
    );

    s_handler = new BurnMintTokenHandler(address(s_token));

    s_token.grantMintAndBurnRoles(address(s_handler));
    s_token.grantMintAndBurnRoles(OWNER);

    address[] memory callers = new address[](1);
    callers[0] = s_bridgeCaller;
    s_handler.applyAuthorizedCallerUpdates(
      AuthorizedCallers.AuthorizedCallerArgs({addedCallers: callers, removedCallers: new address[](0)})
    );
    s_handler.setAdminCaller(s_adminCaller, true);
    s_handler.setSelectorAllowed(BRIDGE_CHAIN_SELECTOR, true);

    s_token.mint(s_bridgeCaller, 10_000e18);
    s_token.mint(s_adminCaller, 10_000e18);
  }

  function _deposit(
    address caller,
    uint64 remoteChainSelector,
    uint256 amount
  ) internal {
    vm.startPrank(caller);
    s_token.approve(address(s_handler), amount);
    s_handler.deposit(address(s_token), remoteChainSelector, amount);
    vm.stopPrank();
  }
}
