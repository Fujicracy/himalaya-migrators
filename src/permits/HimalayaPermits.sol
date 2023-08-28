// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

/**
 * @title HimalayaPermits
 *
 * @author Fujidao Labs
 *
 * @notice
 */

import {MigrationPermitBase} from "../libraries/MigrationPermitBase.sol";
import {IHimalayaMigrator} from "../interfaces/IHimalayaMigrator.sol";
import {EIP712} from "./EIP712.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

contract HimalayaPermits is EIP712 {
  /// @dev Custom Errors
  error HimalayaPermits__expiredDeadline();
  error HimalayaPermits__invalidSignature();

  mapping(address => uint128) private _nonces;

  /// @dev Reserve a slot as recommended in OZ.
  // solhint-disable-next-line var-name-mixedcase
  bytes32 private _PERMIT_TYPEHASH_DEPRECATED_SLOT;

  /**
   * @notice Returns the curent used nonces for permits of `owner`.
   * Based on OZ {IERC20Permit-nonces}.
   *
   * @param owner address to check nonces
   */
  function nonces(address owner) public view returns (uint128) {
    return _nonces[owner];
  }

  /// @dev TODO docs
  function DOMAIN_SEPARATOR() external view returns (bytes32) {
    return _domainSeparatorV4();
  }

  /// @dev TODO docs.
  function _checkMigrationPermit(
    IHimalayaMigrator.Migration memory migration,
    uint8 v,
    bytes32 r,
    bytes32 s
  )
    internal
  {
    _checkDeadline(migration.deadline);

    IHimalayaMigrator.Migration memory permit = _buildMigration(migration);
    bytes32 structHash = _getStructHashMigration(permit);

    _checkSigner(structHash, migration.owner, v, r, s);
  }

  /// Internal Functions

  function _buildMigration(IHimalayaMigrator.Migration memory migration)
    private
    returns (IHimalayaMigrator.Migration memory permit)
  {
    permit.owner = migration.owner;
    permit.toChain = uint48(block.chainid); // should match: migration.toChain
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
    permit.deadline = migration.deadline;
    permit.nonce = _useNonce(migration.owner); // should match: migration.nonce
  }

  function _getStructHashMigration(IHimalayaMigrator.Migration memory permit) private pure returns (bytes32) {
    return keccak256(abi.encode(MigrationPermitBase.MIGRATION_TYPEHASH, permit));
  }

  /**
   * @dev "Consume a nonce": return the current amount and increment.
   * _Available since v4.1._
   *
   * @param owner address who uses a permit
   */
  function _useNonce(address owner) internal returns (uint128 current) {
    current = _nonces[owner];
    unchecked {
      _nonces[owner] += 1;
    }
  }

  /**
   * @dev Reverts if block.timestamp is expired according to `deadline`.
   *
   * @param deadline timestamp to check
   */
  function _checkDeadline(uint256 deadline) private view {
    if (block.timestamp > uint256(deadline)) {
      revert HimalayaPermits__expiredDeadline();
    }
  }

  /**
   * @dev Reverts if `presumedOwner` is not signer of `structHash`.
   *
   * @param structHash of data
   * @param presumedOwner address to check
   * @param v signature value
   * @param r signautre value
   * @param s signature value
   */
  function _checkSigner(
    bytes32 structHash,
    address presumedOwner,
    uint8 v,
    bytes32 r,
    bytes32 s
  )
    internal
    view
  {
    bytes32 digest = _hashTypedDataV4(structHash);
    address signer = ECDSA.recover(digest, v, r, s);
    if (signer != presumedOwner) {
      revert HimalayaPermits__invalidSignature();
    }
  }
}
