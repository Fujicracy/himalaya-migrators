// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

/**
 * @title CompoundV2
 *
 * @author Fujidao Labs
 *
 * @notice This contract allows interaction with CompoundV2.
 *
 * @dev The IAddrMapper needs to be properly configured for CompoundV2
 */

import {LibCompoundV2} from "@fuji-v2/src/libraries/LibCompoundV2.sol";
import {ILendingProvider} from "@fuji-v2/src/interfaces/ILendingProvider.sol";
import {ICToken} from "@fuji-v2/src/interfaces/compoundV2/ICToken.sol";
import {ICERC20} from "@fuji-v2/src/interfaces/compoundV2/ICERC20.sol";
import {ICETH} from "@fuji-v2/src/interfaces/compoundV2/ICETH.sol";
import {IComptroller} from "@fuji-v2/src/interfaces/compoundV2/IComptroller.sol";
import {IWETH9} from "@fuji-v2/src/abstracts/WETH9.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract CompoundV2Helper {
  using Address for address;

  function depositV2(uint256 amount, address asset, address cTokenAddr) public {
    _enterCollatMarketV2(cTokenAddr);

    uint256 balanceCTokenBefore = IERC20(cTokenAddr).balanceOf(address(this));
    if (_isWETH(asset)) {
      ICETH cETH = ICETH(cTokenAddr);
      // unwrap WETH to ETH
      IWETH9(asset).withdraw(amount);

      // cEth reverts if mint unsuccessful
      cETH.mint{value: amount}();
    } else {
      ICERC20 cToken = ICERC20(cTokenAddr);

      cToken.mint(amount);
    }

    uint256 balanceCTokenAfter = IERC20(cTokenAddr).balanceOf(address(this));
    IERC20(cTokenAddr).transfer(msg.sender, balanceCTokenAfter - balanceCTokenBefore);
  }

  function _enterCollatMarketV2(address asset) public {
    IComptroller comptroller = IComptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);

    address[] memory markets = new address[](1);
    markets[0] = asset;
    comptroller.enterMarkets(markets);
  }

  function _isWETH(address asset) private pure returns (bool) {
    return asset == 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  }

  function providerNameV2() private pure returns (string memory) {
    return "Compound_V2";
  }
}
