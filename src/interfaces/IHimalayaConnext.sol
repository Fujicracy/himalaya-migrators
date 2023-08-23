// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

/**
 * @title IHimalayaConnext
 *
 * @author Fujidao Labs
 *
 * @notice Defines interface for {HimalayaConnext} migration operations.
 */

import {IXReceiver} from "@fuji-v2/src/interfaces/connext/IConnext.sol";
import {IHimalayaMigrator} from "./IHimalayaMigrator.sol";

interface IHimalayaConnext is IXReceiver {
  /**
   *
   * @notice Begins a cross-chain migration of a position from origin chain to destination chain.
   *
   * @param migration Migration struct containing all necessary information to execute a cross-chain migration.
   *
   * @return transferId Unique identifier for this migration.
   * @dev Requirements:
   * - `msg.sender` must be HimalayaMigrator contract.
   * - `msg.sender` must be an allowed migrator
   */
  function xCall(IHimalayaMigrator.Migration memory migration)
    external
    returns (bytes32 transferId);

  /**
   *
   * @notice Sets the migrator contract to be allowed to call xCall.
   *
   * @param migrator Address of the migrator contract.
   * @param active Whether the migrator is allowed to call xCall.
   *
   * @dev Requirements:
   * - `msg.sender` must be timelock.
   */
  function setMigrator(address migrator, bool active) external;

  /**
   *
   * @notice Sets the domainIds used to call connext.
   *
   * @param chainIds array of chain ids to be associated with `domainIds`
  * @param domainIds array of domain ids to be associated with `chainIds`
   *
   * @dev Requirements:
   * - `msg.sender` must be timelock.
   */
  function setDomainIds(uint256[] memory chainIds_, uint32[] memory domainIds)
    external;
}
