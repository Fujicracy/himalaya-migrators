// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

/**
 * @title IHimalayaMigrator
 *
 * @author Fujidao Labs
 *
 * @notice Defines interface for {HimalayaMigrator} migration operations.
 */

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

struct Migration {
  address owner;
  uint48 fromChainId;
  uint48 toChainId;
  address fromMarket;
  address toMarket;
  IERC20 assetOrigin;
  IERC20 assetDest;
  uint256 amount;
  IERC20 debtAssetOrigin;
  IERC20 debtAssetDest;
  uint256 debtAmount;
  address himalaya; //address of himalaya on destination chain
  uint48 deadline;
}

interface IHimalayaMigrator {
  function beginXMigration(Migration memory migration) external returns (bytes32 transferId);

  function receiveXMigration(bytes memory data) external returns (bool);
}
