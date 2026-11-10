// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ERC20BurnMintTokenHandler} from "../../../pools/ERC20BurnMintTokenHandler.sol";
import {ERC20LockReleaseTokenHandler} from "../../../pools/ERC20LockReleaseTokenHandler.sol";
import {LockReleaseTokenPool} from "../../../pools/LockReleaseTokenPool.sol";
import {TokenPool} from "../../../pools/TokenPool.sol";
import {BaseERC20} from "../../../tokens/BaseERC20.sol";
import {CrossChainToken} from "../../../tokens/CrossChainToken.sol";
import {BaseTest} from "../../BaseTest.t.sol";

import {IERC20} from "@openzeppelin/contracts@5.3.0/token/ERC20/IERC20.sol";

contract LockReleaseTokenPool_constructor is BaseTest {
  function test_constructor() public {
    CrossChainToken token = new CrossChainToken(
      BaseERC20.ConstructorParams({
        name: "T", symbol: "T", decimals: 18, maxSupply: 0, preMint: 0, preMintRecipient: address(0), ccipAdmin: OWNER
      }),
      OWNER,
      OWNER
    );
    ERC20LockReleaseTokenHandler tokenHandler = new ERC20LockReleaseTokenHandler(address(token));

    LockReleaseTokenPool pool = new LockReleaseTokenPool(
      IERC20(address(token)),
      DEFAULT_TOKEN_DECIMALS,
      address(0),
      address(s_mockRMNRemote),
      address(s_sourceRouter),
      address(tokenHandler)
    );

    assertEq(address(pool.getToken()), address(token));
    assertEq(pool.getTokenHandler(), address(tokenHandler));
    assertEq(pool.typeAndVersion(), "LockReleaseTokenPool 2.0.0");
  }

  function test_constructor_RevertWhen_InvalidTokenHandler() public {
    CrossChainToken token = new CrossChainToken(
      BaseERC20.ConstructorParams({
        name: "T", symbol: "T", decimals: 18, maxSupply: 0, preMint: 0, preMintRecipient: address(0), ccipAdmin: OWNER
      }),
      OWNER,
      OWNER
    );
    ERC20BurnMintTokenHandler tokenHandler = new ERC20BurnMintTokenHandler(address(token));

    vm.expectRevert(abi.encodeWithSelector(LockReleaseTokenPool.InvalidTokenHandler.selector, address(tokenHandler)));
    new LockReleaseTokenPool(
      IERC20(address(token)),
      DEFAULT_TOKEN_DECIMALS,
      address(0),
      address(s_mockRMNRemote),
      address(s_sourceRouter),
      address(tokenHandler)
    );
  }

  function test_constructor_RevertWhen_InvalidToken() public {
    CrossChainToken token = new CrossChainToken(
      BaseERC20.ConstructorParams({
        name: "T", symbol: "T", decimals: 18, maxSupply: 0, preMint: 0, preMintRecipient: address(0), ccipAdmin: OWNER
      }),
      OWNER,
      OWNER
    );
    ERC20LockReleaseTokenHandler tokenHandler = new ERC20LockReleaseTokenHandler(address(token));

    CrossChainToken invalidToken = new CrossChainToken(
      BaseERC20.ConstructorParams({
        name: "IT", symbol: "IT", decimals: 18, maxSupply: 0, preMint: 0, preMintRecipient: address(0), ccipAdmin: OWNER
      }),
      OWNER,
      OWNER
    );

    vm.expectRevert(abi.encodeWithSelector(TokenPool.InvalidToken.selector, address(invalidToken)));
    new LockReleaseTokenPool(
      IERC20(address(invalidToken)),
      DEFAULT_TOKEN_DECIMALS,
      address(0),
      address(s_mockRMNRemote),
      address(s_sourceRouter),
      address(tokenHandler)
    );
  }
}
