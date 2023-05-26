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
    address asset;
    uint256 amount;
    address debtAsset;
    uint256 debtAmount;
    uint128 fromChain;
    uint128 toChain;
  }

  function beginXMigration(Migration memory migration) external returns (bytes32 transferId);

  function receiveXMigration(bytes memory data) external returns (bool);
}
