// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

/**
 * @title LibSignMigration
 *
 * @author Fujidao Labs
 *
 * @notice Helper library for permit signing of lending-borrowing position migrations.
 */

import {MigrationPermitBase, MigrationPermit} from "./MigrationPermitBase.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {HimalayaBase} from "../migrators/HimalayaBase.sol";

library LibSignMigration {
  /// @notice Returns the struct type of a permit used for `borrow()` or `withdraw()`.
  function buildPermitStruct(
    address owner,
    uint48 fromChain,
    uint48 toChain,
    address fromMarket,
    address toMarket,
    IERC20 assetOrigin,
    IERC20 assetDest,
    uint256 amount,
    IERC20 debtAssetOrigin,
    IERC20 debtAssetDest,
    uint256 debtAmount,
    address himalaya
  )
    public
    view
    returns (MigrationPermit memory permit)
  {
    permit.owner = owner;
    permit.fromChainId = fromChain;
    permit.toChainId = toChain;
    permit.fromMarket = fromMarket;
    permit.toMarket = toMarket;
    permit.assetOrigin = assetOrigin;
    permit.assetDest = assetDest;
    permit.amount = amount;
    permit.debtAssetOrigin = debtAssetOrigin;
    permit.debtAssetDest = debtAssetDest;
    permit.debtAmount = debtAmount;
    permit.himalaya = himalaya;
    permit.deadline = uint256(block.timestamp + 0.25 days);
    permit.nonce = HimalayaBase(himalaya).nonces(owner);
  }

  /// @notice Returns the hash of a permit-withdraw.
  function getStructHashMigration(MigrationPermit memory permit) public pure returns (bytes32) {
    return keccak256(abi.encode(MigrationPermitBase.PERMIT_MIGRATION_TYPEHASH, permit));
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
