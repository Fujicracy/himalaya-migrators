// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

/**
 * @title CompoundV2
 *
 * @author Fujidao Labs
 *
 * @notice This contract allows interaction with CompoundV2.
 *
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

contract CompoundV2 {
  using Address for address;

  /// @dev Custom errors
  error CompoundV2__deposit_failed(uint256 status);
  error CompoundV2__borrow_failed(uint256 status);
  error CompoundV2__withdraw_failed(uint256 status);
  error CompoundV2__payback_failed(uint256 status);

  receive() external payable {}

  /**
   * @dev Approves assets as collateral for Compound Protocol.
   *
   * @param asset address of the 'asset' to be approved as collateral.
   */
  function _enterCollatMarket(address asset) internal {
    IComptroller comptroller = IComptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);

    address[] memory markets = new address[](1);
    markets[0] = asset;
    comptroller.enterMarkets(markets);
  }

  /**
   * @dev Returns true/false wether the given token is/isn't WETH.
   *
   * @param asset address of the token
   */
  function _isWETH(address asset) internal pure returns (bool) {
    return asset == 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  }

  function withdrawV2(
    uint256 amount,
    address asset,
    address cTokenAddr
  )
    internal
    returns (bool success)
  {
    ICToken cToken = ICToken(cTokenAddr);

    uint256 status = cToken.redeemUnderlying(amount);
    if (status != 0) {
      revert CompoundV2__withdraw_failed(status);
    }

    // wrap ETH to WETH
    if (_isWETH(asset)) {
      IWETH9(asset).deposit{value: amount}();
    }
    success = true;
  }

  function paybackV2(
    address user,
    uint256 amount,
    address asset,
    address cTokenAddr
  )
    internal
    returns (bool success)
  {
    if (_isWETH(asset)) {
      ICETH cETH = ICETH(cTokenAddr);
      // unwrap WETH to ETH
      IWETH9(asset).withdraw(amount);

      cETH.repayBorrowBehalf{value: amount}(user);
    } else {
      ICERC20 cToken = ICERC20(cTokenAddr);

      uint256 status = cToken.repayBorrowBehalf(user, amount);
      if (status != 0) {
        revert CompoundV2__payback_failed(status);
      }
    }
    success = true;
  }

  function getDepositBalanceV2(
    address user,
    address cTokenAddr
  )
    public
    view
    returns (uint256 balance)
  {
    ICToken cToken = ICToken(cTokenAddr);
    balance = LibCompoundV2.viewUnderlyingBalanceOf(cToken, user);
  }

  function getBorrowBalanceV2(
    address user,
    address cTokenAddr
  )
    public
    view
    returns (uint256 balance)
  {
    ICToken cToken = ICToken(cTokenAddr);
    balance = LibCompoundV2.viewBorrowingBalanceOf(cToken, user);
  }
}
