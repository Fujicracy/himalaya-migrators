// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

/**
 * @title HimalayaCompound
 *
 * @author Fujidao Labs
 *
 * @notice This contract allows Fuji Himalaya to receive calls from connext and handle migrations.
 */

import {IHimalayaMigrator} from "../interfaces/IHimalayaMigrator.sol";
import {IHimalayaBase} from "../interfaces/IHimalayaBase.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IConnext, IXReceiver} from "@fuji-v2/src/interfaces/connext/IConnext.sol";

contract HimalayaBase is IXReceiver, IHimalayaBase {
  using SafeERC20 for IERC20;

  IConnext public immutable connext;

  //chainId => migrator
  mapping(uint32 => address) public migrators;

  constructor(address _connext) {
    connext = IConnext(_connext);
  }

  /**
   * @notice Called by Connext on the destination chain.
   *
   * @param transferId the unique identifier of the crosschain transfer
   * @param amount the amount of transferring asset, after slippage, the recipient address receives
   * @param asset the asset being transferred
   * @param originSender the address of the contract or EOA that called xcall on the origin chain
   * @param originDomain the origin domain identifier according Connext nomenclature
   * @param callData the calldata that will get decoded and executed, see "Requirements"
   *
   */
  function xReceive(
    bytes32 transferId,
    uint256 amount,
    address asset,
    address originSender,
    uint32 originDomain,
    bytes memory callData
  )
    external
    returns (bytes memory)
  {
    //TODO check params

    //@dev asset of migration struct is the address on origin chain. We want the asset address on the destination chain
    IHimalayaMigrator.Migration memory migration =
      abi.decode(callData, (IHimalayaMigrator.Migration));
    migration.asset = asset;

    //Approve IHimalayaMigrator to pull funds
    IERC20(migration.asset).safeApprove(migration.himalaya, migration.amount);

    //Handle inbound
    IHimalayaMigrator(migration.himalaya).receiveXMigration(callData);

    return "";
  }

  function xCall(IHimalayaMigrator.Migration memory migration)
    external
    returns (bytes32 transferId)
  {
    //Pull funds from IHimalayaMigrator
    IERC20(migration.asset).safeTransferFrom(msg.sender, address(this), migration.amount);

    //Approve connext to pull funds
    IERC20(migration.asset).safeApprove(address(connext), migration.amount);

    //TODO
    transferId = connext.xcall(
      // _destination: Domain ID of the destination chain
      uint32(migration.toChain),
      // _to: address of the target contract
      migration.himalaya,
      // _asset: address of the token contract
      migration.asset,
      // _delegate: address that has rights to update the original slippage tolerance
      // by calling Connext's forceUpdateSlippage function
      migration.himalaya, //TODO check this parameter
      // _amount: amount of tokens to transfer
      migration.amount,
      // _slippage: can be anything between 0-10000 because
      // the maximum amount of slippage the user will accept in BPS, 30 == 0.3%
      30, //TODO implement this
      // _callData: empty because we're only sending funds
      abi.encode(migration)
    );
  }

  function addMigrator(uint32 domainId, address migrator) external {
    //TODO define modifier
    require(migrators[domainId] == address(0), "HimalayaMigrator: migrator already exists");
    migrators[domainId] = migrator;
  }
}
