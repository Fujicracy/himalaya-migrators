// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

/**
 * @title HimalayaCompound
 *
 * @author Fujidao Labs
 *
 * @notice This contract allows migrating positions between Compound instances using Himalaya.
 */

import {IHimalayaMigrator} from "../interfaces/IHimalayaMigrator.sol";

contract HimalayaCompound is IHimalayaMigrator {
    function beginXMigration(Migration memory migration) public returns (bytes32 transferId) {
        return bytes32("");
    }

    function receiveXMigration(bytes memory data) public returns (bool) {
        return true;
    }

    function _handleOutboundV2toV3() internal returns (bool) {}

    function _handleOutboundV3toV3() internal returns (bool) {}

    function _handleInboundV2toV3() internal returns (bool) {}

    function _handleInboundV3toV3() internal returns (bool) {}
}
