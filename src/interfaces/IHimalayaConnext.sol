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
  function xCall(IHimalayaMigrator.Migration memory migration)
    external
    returns (bytes32 transferId);
}
