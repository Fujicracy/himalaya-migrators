// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

/**
 * @title MigrationPermitBase
 *
 * @author Fujidao Labs
 *
 * @notice Defines the migration typehash.
 */

library MigrationPermitBase {
  bytes32 internal constant MIGRATION_TYPEHASH = keccak256(
    abi.encodePacked(
      "Migration(",
      "address owner,",
      "uint48 toChain,",
      "address fromMarket,",
      "address toMarket,",
      "IERC20 assetOrigin,",
      "IERC20 assetDest,",
      "uint256 amount,",
      "IERC20 debtAssetOrigin,",
      "IERC20 debtAssetDest,",
      "uint256 debtAmount,",
      "address himalaya,",
      "uint48 slippage,",
      "uint128 deadline,",
      "uint128 nonce"
    )
  );
}
