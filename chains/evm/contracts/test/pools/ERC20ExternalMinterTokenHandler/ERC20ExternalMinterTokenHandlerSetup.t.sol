// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IBurnMintERC20} from "../../../interfaces/IBurnMintERC20.sol";
import {IExternalMinter} from "../../../interfaces/IExternalMinter.sol";
import {ERC20ExternalMinterTokenHandler} from "../../../pools/ERC20ExternalMinterTokenHandler.sol";
import {BaseERC20} from "../../../tokens/BaseERC20.sol";
import {CrossChainToken} from "../../../tokens/CrossChainToken.sol";
import {BaseTest} from "../../BaseTest.t.sol";
import {AuthorizedCallers} from "@chainlink/contracts/src/v0.8/shared/access/AuthorizedCallers.sol";

import {IERC20} from "@openzeppelin/contracts@5.3.0/token/ERC20/IERC20.sol";

contract MockExternalMinter is IExternalMinter {
  address internal immutable i_token;

  constructor(
    address token
  ) {
    i_token = token;
  }

  function getToken() external view override returns (address) {
    return i_token;
  }

  function mint(
    address recipient,
    uint256 amount
  ) external override returns (bool) {
    IBurnMintERC20(i_token).mint(recipient, amount);
    return true;
  }

  function burn(
    uint256 amount
  ) external override returns (bool) {
    IERC20(i_token).transferFrom(msg.sender, address(this), amount);
    IBurnMintERC20(i_token).burn(amount);
    return true;
  }
}

contract ERC20ExternalMinterTokenHandlerSetup is BaseTest {
  CrossChainToken internal s_token;
  MockExternalMinter internal s_minter;
  ERC20ExternalMinterTokenHandler internal s_handler;
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

    s_minter = new MockExternalMinter(address(s_token));
    s_token.grantMintAndBurnRoles(address(s_minter));
    s_token.grantMintAndBurnRoles(OWNER);

    s_handler = new ERC20ExternalMinterTokenHandler(address(s_token), address(s_minter));

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
}
