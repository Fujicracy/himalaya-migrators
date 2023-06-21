// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

/**
 * @title HimalayaCompound
 *
 * @author Fujidao Labs
 *
 * @notice This contract allows migrating positions between Compound instances using Himalaya.
 */

import {IHimalayaMigrator} from "../interfaces/IHimalayaMigrator.sol";
import {CompoundV2} from "../integrations/CompoundV2.sol";
import {CompoundV3} from "../integrations/CompoundV3.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IHimalayaConnext} from "../interfaces/IHimalayaConnext.sol";

contract HimalayaCompound is IHimalayaMigrator, CompoundV2, CompoundV3 {
  using SafeERC20 for IERC20;

  //@dev custom error
  error HimalayaCompound__beginXMigration_marketNotSupported();
  error HimalayaCompound__receiveXMigration_marketNotSupported();
  error HimalayaCompound__handleOutboundFromV2_invalidAmount();
  error HimalayaCompound__handleOutboundFromV3_invalidAmount();
  error HimalayaCompound__beginXMigration_fromChainNotSupported();
  error HimalayaCompound__addMarketsDestChain_invalidInput();

  mapping(address => bool) public isMarketV2;
  mapping(address => bool) public isMarketV3;

  //destChainId => marketOnDestChain => isMarketOnDestChain
  mapping(uint48 => mapping(address => bool)) public isMarketOnDestChain;

  IHimalayaConnext public immutable himalayaConnext;

  constructor(address _himalayaConnext) {
    himalayaConnext = IHimalayaConnext(_himalayaConnext);
  }

  function beginXMigration(Migration memory migration) external returns (bytes32 transferId) {
    if (block.chainid != migration.fromChain) {
      revert HimalayaCompound__beginXMigration_fromChainNotSupported();
    }
    if (!isMarketOnDestChain[migration.toChain][migration.toMarket]) {
      revert HimalayaCompound__beginXMigration_marketNotSupported();
    }

    //Identify market
    if (isMarketV2[migration.fromMarket]) {
      _handleOutboundFromV2(
        migration.owner, migration.fromMarket, migration.assetOrigin, migration.amount
      );
    } else if (isMarketV3[migration.fromMarket]) {
      _handleOutboundFromV3(
        migration.owner, migration.fromMarket, migration.assetOrigin, migration.amount
      );
    } else {
      revert HimalayaCompound__beginXMigration_marketNotSupported();
    }

    //Approve himalayaConnext to pull funds
    migration.assetOrigin.safeIncreaseAllowance(address(himalayaConnext), migration.amount);

    transferId = himalayaConnext.xCall(migration);
  }

  function receiveXMigration(bytes memory data) external returns (bool) {
    Migration memory migration = abi.decode(data, (Migration));
    //TODO check parameters

    if (!isMarketV3[migration.toMarket]) {
      revert HimalayaCompound__receiveXMigration_marketNotSupported();
    }

    //Pull funds from HimalayaConnext
    SafeERC20.safeTransferFrom(migration.assetDest, msg.sender, address(this), migration.amount);

    _handleInboundToV3(
      migration.owner,
      migration.toMarket,
      migration.assetDest,
      migration.amount,
      migration.debtAssetDest,
      migration.debtAmount
    );

    return true;
  }

  function addMarketsDestChain(uint48[] memory chainIds, address[] memory markets) external {
    if (chainIds.length != markets.length) {
      revert HimalayaCompound__addMarketsDestChain_invalidInput();
    }

    for (uint256 i = 0; i < chainIds.length; i++) {
      isMarketOnDestChain[chainIds[i]][markets[i]] = true;
    }
  }

  function addMarketsV2(address[] memory markets) external {
    for (uint256 i = 0; i < markets.length; i++) {
      isMarketV2[markets[i]] = true;
    }
  }

  function addMarketsV3(address[] memory markets) external {
    for (uint256 i = 0; i < markets.length; i++) {
      isMarketV3[markets[i]] = true;
    }
  }

  function _handleOutboundFromV2(
    address owner,
    address fromMarket,
    IERC20 asset,
    uint256 amount
  )
    internal
    returns (bool)
  {
    if (amount == 0 || amount > getDepositBalanceV2(owner, fromMarket)) {
      revert HimalayaCompound__handleOutboundFromV2_invalidAmount();
    }

    //Pull cTokens from user
    uint256 cTokenBalance = IERC20(fromMarket).balanceOf(owner);
    SafeERC20.safeTransferFrom(IERC20(fromMarket), owner, address(this), cTokenBalance);

    //Withdraw funds from V2
    withdrawV2(amount, address(asset), fromMarket);

    return true;
  }

  function _handleOutboundFromV3(
    address owner,
    address fromMarket,
    IERC20 asset,
    uint256 amount
  )
    internal
    returns (bool)
  {
    if (amount == 0 || amount > getDepositBalanceV3(owner, address(asset), fromMarket)) {
      revert HimalayaCompound__handleOutboundFromV3_invalidAmount();
    }

    //TODO payback?

    //Withdraw funds from V3
    withdrawV3(owner, address(this), amount, address(asset), fromMarket);

    return true;
  }

  function _handleInboundToV3(
    address owner,
    address toMarket,
    IERC20 asset,
    uint256 amount,
    IERC20 debtAsset,
    uint256 debtAmount
  )
    internal
    returns (bool)
  {
    asset.safeIncreaseAllowance(toMarket, amount);
    depositV3(owner, amount, address(asset), toMarket);

    borrowV3(owner, debtAmount, address(debtAsset), toMarket);

    return true;
  }
}
