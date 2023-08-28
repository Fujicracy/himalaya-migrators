// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

/**
 * @title LibSignMigration
 *
 * @author Fujidao Labs
 *
 * @notice Helper library for permit signing of lending-borrowing position migrations.
 */

import {IHimalayaMigrator} from "../interfaces/IHimalayaMigrator.sol";
import {MigrationPermitBase} from "./MigrationPermitBase.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {HimalayaPermits} from "../permits/HimalayaPermits.sol";

library LibSignMigration {
  /// @notice Returns the struct type of a permit used for `borrow()` or `withdraw()`.
  function prepareMigrationStructForSigning(IHimalayaMigrator.Migration memory migration)
    public
    view
    returns (IHimalayaMigrator.Migration memory permit)
  {
    permit.owner = migration.owner;
    permit.toChain = migration.toChain;
    permit.fromMarket = migration.fromMarket;
    permit.toMarket = migration.toMarket;
    permit.assetOrigin = migration.assetOrigin;
    permit.assetDest = migration.assetDest;
    permit.amount = migration.amount;
    permit.debtAssetOrigin = migration.debtAssetOrigin;
    permit.debtAssetDest = migration.debtAssetDest;
    permit.debtAmount = migration.debtAmount;
    permit.himalaya = migration.himalaya;
    permit.slippage = migration.slippage;
    permit.deadline = uint128(block.timestamp + 12 hours);
    permit.nonce = HimalayaPermits(migration.himalaya).nonces(migration.owner);
  }

  /// @notice Returns the structhash of a permit-withdraw.
  function getStructHashMigration(IHimalayaMigrator.Migration memory permit)
    public
    pure
    returns (bytes32)
  {
    return keccak256(abi.encode(MigrationPermitBase.MIGRATION_TYPEHASH, permit));
  }

  /// @notice Returns the digest.
  function getHashTypedDataV4Digest(
    bytes32 domainSeparator,
    bytes32 structHash
  )
    external
    pure
    returns (bytes32)
  {
    return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
  }
}
