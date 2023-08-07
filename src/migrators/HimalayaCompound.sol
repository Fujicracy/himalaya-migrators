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
  error HimalayaCompound__addMarketsDestChain_invalidInput();
  error HimalayaCompound__onlyAdmin_notAuthorized();
  error HimalayaCompound__handleOutboundFromV2_invalidDebtAmount();

  //marketAddress => isMarket
  mapping(address => bool) public isMarketV2;
  mapping(address => bool) public isMarketV3;

  //destChainId => marketOnDestChain => isMarketOnDestChain
  mapping(uint48 => mapping(address => bool)) public isMarketOnDestChain;

  IHimalayaConnext public immutable himalayaConnext;

  address public immutable admin;

  modifier onlyAdmin() {
    if (msg.sender != admin) {
      revert HimalayaCompound__onlyAdmin_notAuthorized();
    }
    _;
  }

  constructor(address _himalayaConnext) {
    himalayaConnext = IHimalayaConnext(_himalayaConnext);
    admin = msg.sender;
  }

  function beginXMigration(Migration memory migration) external returns (bytes32 transferId) {
    if (!isMarketOnDestChain[migration.toChain][migration.toMarket]) {
      revert HimalayaCompound__beginXMigration_marketNotSupported();
    }

    //Identify market
    if (isMarketV2[migration.fromMarket]) {
      _handleOutboundFromV2(
        migration
      );
    } else if (isMarketV3[migration.fromMarket]) {
      _handleOutboundFromV3(
        migration
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

  function addMarketsDestChain(
    uint48[] memory chainIds,
    address[] memory markets
  )
    external
    onlyAdmin
  {
    if (chainIds.length != markets.length) {
      revert HimalayaCompound__addMarketsDestChain_invalidInput();
    }

    for (uint256 i = 0; i < chainIds.length; i++) {
      isMarketOnDestChain[chainIds[i]][markets[i]] = true;
    }
  }

  function addMarketsV2(address[] memory markets) external onlyAdmin {
    for (uint256 i = 0; i < markets.length; i++) {
      isMarketV2[markets[i]] = true;
    }
  }

  function addMarketsV3(address[] memory markets) external onlyAdmin {
    for (uint256 i = 0; i < markets.length; i++) {
      isMarketV3[markets[i]] = true;
    }
  }

  function _handleOutboundFromV2(
    Migration memory migration
  )
    internal
    returns (bool)
  {
    if (migration.amount == 0) {
      revert HimalayaCompound__handleOutboundFromV2_invalidAmount();
    }
    if (migration.amount > getDepositBalanceV2(migration.owner, migration.fromMarket)) {
      migration.amount = getDepositBalanceV2(migration.owner, migration.fromMarket);
    }
    if (migration.debtAmount != 0) {
      if (migration.debtAmount > getBorrowBalanceV2(migration.owner, migration.fromDebtMarket)) {
        migration.debtAmount = getBorrowBalanceV2(migration.owner, migration.fromDebtMarket);
      }
      //Pull debt tokens from user
      SafeERC20.safeTransferFrom(migration.debtAssetOrigin, migration.owner, address(this), migration.debtAmount);
      //Approve debt tokens to be repaid
      SafeERC20.safeIncreaseAllowance(migration.debtAssetOrigin, migration.fromDebtMarket, migration.debtAmount);
      //Repay debt
      paybackV2(migration.owner, migration.debtAmount, address(migration.debtAssetOrigin), migration.fromDebtMarket);
    }

    //Pull cTokens from user
    uint256 cTokenBalance = IERC20(migration.fromMarket).balanceOf(migration.owner);
    SafeERC20.safeTransferFrom(IERC20(migration.fromMarket), migration.owner, address(this), cTokenBalance);

    //Withdraw funds from V2
    withdrawV2(migration.amount, address(migration.assetOrigin), migration.fromMarket);

    return true;
  }

  function _handleOutboundFromV3(
    Migration memory migration
  )
    internal
    returns (bool)
  {
    if (migration.amount == 0 || migration.amount > getDepositBalanceV3(migration.owner, address(migration.assetOrigin), migration.fromMarket)) {
      revert HimalayaCompound__handleOutboundFromV3_invalidAmount();
    }

    //Withdraw funds from V3
    withdrawV3(migration.owner, address(this), migration.amount, address(migration.assetOrigin), migration.fromMarket);

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
