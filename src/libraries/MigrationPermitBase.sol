// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

struct MigrationPermit {
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
  address himalaya;
  uint256 deadline;
  uint256 nonce;
}

library MigrationPermitBase {
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
      "uint256 deadline,",
      "uint256 nonce"
    )
  );
}
