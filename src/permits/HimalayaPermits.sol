// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

/**
 * @title HimalayaPermits
 *
 * @author Fujidao Labs
 *
 * @notice
 */

import {HimalayaBase} from "../migrators/HimalayaBase.sol";
import {Migration} from "../interfaces/IHimalayaMigrator.sol";
import {EIP712} from "./EIP712.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

contract HimalayaPermits is EIP712 {
  /// @dev Custom Errors
  error HimalayaPermits__expiredDeadline();
  error HimalayaPermits__invalidSignature();

  mapping(address => uint48) private _nonces;

  // solhint-disable-next-line var-name-mixedcase
  bytes32 internal constant PERMIT_MIGRATION_TYPEHASH = keccak256(
      abi.encodePacked(
        "MigrationPermit(",
        "address owner,",
        "uint48 fromChainId,",
        "uint48 toChainId,",
        "address fromMarket,",
        "address toMarket,",
        "IERC20 assetOrigin,",
        "IERC20 assetDest,",
        "uint256 amount,",
        "IERC20 debtAssetOrigin,",
        "IERC20 debtAssetDest,",
        "uint256 debtAmount,",
        "address himalaya,",
        "uint48 nonce,",
        "uint48 deadline"
      )
  );

  /// @dev Reserve a slot as recommended in OZ {draft-ERC20Permit}.
  // solhint-disable-next-line var-name-mixedcase
  bytes32 private _PERMIT_TYPEHASH_DEPRECATED_SLOT;

  /// @dev TODO docs
  function nonces(address owner) public view returns (uint48) {
    return _nonces[owner];
  }

  /// @dev TODO docs
  // solhint-disable-next-line func-name-mixedcase
  function DOMAIN_SEPARATOR() external view returns (bytes32) {
    return _domainSeparatorV4();
  }

  /// @dev TODO docs.
  function _checkMigrationPermit(
    Migration memory migration,
    uint48 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  )
    internal
    view
  {
    _checkDeadline(deadline);
    bytes32 structHash = keccak256(
      abi.encode(
          PERMIT_MIGRATION_TYPEHASH,
          migration.owner,
          migration.fromChainId,
          uint48(block.chainid), // should match: migration.toChainId
          migration.fromMarket,
          migration.toMarket,
          migration.assetOrigin,
          migration.assetDest,
          migration.amount,
          migration.debtAssetOrigin,
          migration.debtAssetDest,
          migration.debtAmount,
          migration.himalaya,
          _useNonce(migration.owner),
          deadline
      )
    );
    _checkSigner(structHash, migration.owner, v, r, s);
  }

  /// Internal Functions

  /**
   * @dev "Consume a nonce": return the current amount and increment.
   * _Available since v4.1._
   *
   * @param owner address who uses a permit
   */
  function _useNonce(address owner) internal returns (uint48 current) {
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
  function _checkDeadline(uint48 deadline) private view {
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
