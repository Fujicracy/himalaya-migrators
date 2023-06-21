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

interface IHimalayaMigrator {
  struct Migration {
    address owner; // user who wants to migrate or owner of the position to be migrated
    uint48 fromChain; // chain from which position will be migrated
    uint48 toChain; // chain to which migration will be sent to
    address fromMarket; // market on origin chain which owner's position is in
    address toMarket; // market on destination chain which owner's position will be migrated to
    IERC20 assetOrigin; // ERC20 token that is deposited on origin chain
    IERC20 assetDest; // adopted ERC20 token that represents origin asset at destination chain
    uint256 amount; // amount of ERC20 deposit to be migrated
    IERC20 debtAssetOrigin; // ERC20 token that is borrowed on origin chain
    IERC20 debtAssetDest; // adopted ERC20 token that represent origin debt asset at destination chain
    uint256 debtAmount; // amount of debt being migrated
    address himalaya; //address of IHimalayaMigrator on destination chain
    uint256 deadline; //period to execute this migration
  }

  function beginXMigration(Migration memory migration) external returns (bytes32 transferId);

  function receiveXMigration(bytes memory data) external returns (bool);
}
