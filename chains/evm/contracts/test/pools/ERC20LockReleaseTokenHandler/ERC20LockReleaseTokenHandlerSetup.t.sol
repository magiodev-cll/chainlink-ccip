// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ERC20LockReleaseTokenHandler} from "../../../pools/ERC20LockReleaseTokenHandler.sol";
import {BaseERC20} from "../../../tokens/BaseERC20.sol";
import {CrossChainToken} from "../../../tokens/CrossChainToken.sol";
import {BaseTest} from "../../BaseTest.t.sol";
import {AuthorizedCallers} from "@chainlink/contracts/src/v0.8/shared/access/AuthorizedCallers.sol";

import {IERC20} from "@openzeppelin/contracts@5.3.0/token/ERC20/IERC20.sol";

contract ERC20LockReleaseTokenHandlerSetup is BaseTest {
  IERC20 internal s_token;
  ERC20LockReleaseTokenHandler internal s_handler;
  address internal s_bridgeCaller = makeAddr("bridge_caller");
  address internal s_adminCaller = makeAddr("admin_caller");
  address internal s_recipient = makeAddr("recipient");

  uint64 internal constant BRIDGE_CHAIN_SELECTOR = DEST_CHAIN_SELECTOR;
  uint64 internal constant OTHER_CHAIN_SELECTOR = SOURCE_CHAIN_SELECTOR;

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
    deal(address(s_token), s_bridgeCaller, type(uint256).max);
    deal(address(s_token), s_adminCaller, type(uint256).max);

    s_handler = new ERC20LockReleaseTokenHandler(address(s_token));

    address[] memory callers = new address[](1);
    callers[0] = s_bridgeCaller;
    s_handler.applyAuthorizedCallerUpdates(
      AuthorizedCallers.AuthorizedCallerArgs({addedCallers: callers, removedCallers: new address[](0)})
    );
    s_handler.setAdminCaller(s_adminCaller, true);
    s_handler.setSelectorAllowed(BRIDGE_CHAIN_SELECTOR, true);
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
