// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

/**
 * @title CompoundV3
 *
 * @author Fujidao Labs
 *
 * @notice This contract allows interaction with CompoundV3.
 *
 * @dev The IAddrMapper needs to be properly configured for CompoundV3.
 * See `_getMarketAndAssets`.
 */

import {ICompoundV3} from "@fuji-v2/src/interfaces/compoundV3/ICompoundV3.sol";

contract CompoundV3 {
  /// @dev Custom errors
  error CompoundV3__wrongMarket();

  function depositV3(
    address user,
    uint256 amount,
    address asset,
    address cMarketV3
  )
    internal
    returns (bool success)
  {
    ICompoundV3(cMarketV3).supplyTo(user, asset, amount);
    success = true;
  }

  function borrowV3(
    address user,
    uint256 amount,
    address debtAsset,
    address cMarketV3
  )
    internal
    returns (bool success)
  {
    // From Comet docs: "The base asset can be borrowed using the withdraw function"
    ICompoundV3(cMarketV3).withdrawFrom(user, user, debtAsset, amount);
    success = true;
  }

  function withdrawV3(
    address user,
    uint256 amount,
    address asset,
    address cMarketV3
  )
    internal
    returns (bool success)
  {
    ICompoundV3(cMarketV3).withdrawFrom(user, user, asset, amount);
    success = true;
  }

  function paybackV3(
    uint256 amount,
    address debtAsset,
    address cMarketV3
  )
    internal
    returns (bool success)
  {
    // From Coment docs: 'supply' the base asset to repay an open borrow of the base asset.
    ICompoundV3(cMarketV3).supply(debtAsset, amount);
    success = true;
  }

  function getDepositBalanceV3(
    address user,
    address asset,
    address cMarketV3
  )
    external
    view
    returns (uint256 balance)
  {
    if (asset == ICompoundV3(cMarketV3).baseToken()) {
      balance = ICompoundV3(cMarketV3).balanceOf(user);
    } else {
      balance = ICompoundV3(cMarketV3).collateralBalanceOf(user, asset);
    }
  }

  function getBorrowBalanceV3(
    address user,
    address debtAsset,
    address cMarketV3
  )
    external
    view
    returns (uint256 balance)
  {
    if (debtAsset == ICompoundV3(cMarketV3).baseToken()) {
      balance = ICompoundV3(cMarketV3).borrowBalanceOf(user);
    }
  }

}
