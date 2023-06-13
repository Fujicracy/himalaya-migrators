// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

/**
 * @title IHimalayaMigrator
 *
 * @author Fujidao Labs
 *
 * @notice Defines interface for {HimalayaMigrator} migration operations.
 */

struct Migration {
  address owner;
  uint48 fromChainId;
  uint48 toChainId;
  address fromMarket;
  address toMarket;
  address asset; // address of asset on origin chain
  uint256 amount;
  address debtAsset; //address of debtAsset on destination chain
  uint256 debtAmount;
  address himalaya; //address of himalaya on destination chain
}

interface IHimalayaMigrator {
  function beginXMigration(Migration memory migration) external returns (bytes32 transferId);

  function receiveXMigration(bytes memory data) external returns (bool);
}
