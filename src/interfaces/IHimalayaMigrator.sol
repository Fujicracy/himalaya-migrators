// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

/**
 * @title IHimalayaMigrator
 *
 * @author Fujidao Labs
 *
 * @notice Defines interface for {HimalayaMigrator} migration operations.
 */

interface IHimalayaMigrator {
  struct Migration {
    address owner;
    address fromMarket;
    address toMarket;
    IERC20 assetOrigin;
    IERC20 assetDest;
    uint256 amount;
    IERC20 debtAssetOrigin;
    IERC20 debtAssetDest;
    uint256 debtAmount;
    uint128 fromChain;
    uint128 toChain;
    address himalaya; //address of himalaya on destination chain
  }

  function beginXMigration(Migration memory migration) external returns (bytes32 transferId);

  function receiveXMigration(bytes memory data) external returns (bool);
}
