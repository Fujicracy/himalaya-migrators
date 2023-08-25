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
import {IHimalayaConnext} from "../interfaces/IHimalayaConnext.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IConnext, IXReceiver} from "@fuji-v2/src/interfaces/connext/IConnext.sol";
import {HimalayaPermits} from "../permits/HimalayaPermits.sol";
import {SystemAccessControl} from "@fuji-v2/src/access/SystemAccessControl.sol";

contract HimalayaConnext is HimalayaPermits, IXReceiver, IHimalayaConnext, SystemAccessControl {
  using SafeERC20 for IERC20;

  //@dev custom error
  error HimalayaConnext__onlyAllowedMigrator_notAuthorized();
  error HimalayaConnext__setDomainIds_invalidInput();

  IConnext public immutable connext;

  //chainId => himalayaConnexts
  mapping(uint256 => address) public himalayaConnexts;

  //chainId => domainIdConnext
  mapping(uint256 => uint32) public domainIds;

  //migrator => isAllowed
  mapping(address => bool) public allowedMigrator;

  modifier onlyAllowedMigrator() {
    if (!allowedMigrator[msg.sender]) {
      revert HimalayaConnext__onlyAllowedMigrator_notAuthorized();
    }
    _;
  }

  constructor(address _connext, address chief) {
    connext = IConnext(_connext);
    __SystemAccessControl_init(chief);
  }

  // * @param transferId the unique identifier of the crosschain transfer
  // * @param amount the amount of transferring asset, after slippage, the recipient address receives
  // * @param asset the asset being transferred
  // * @param originSender the address of the contract or EOA that called xcall on the origin chain
  // * @param originDomain the origin domain identifier according Connext nomenclature
  /**
   * @notice Called by Connext on the destination chain.
   *
   * @param callData the calldata that will get decoded and executed, see "Requirements"
   *
   */
  function xReceive(
    bytes32 transferId,
    uint256, /* amount */
    address, /* asset */
    address, /* originSender */
    uint32, /* originDomain */
    bytes memory callData
  )
    external
    returns (bytes memory)
  {
    //TODO check params - implement with permits
    //NOTE ensure checking the slipped amount and replace in migration struct,
    // because 99% of the time `amount` != Migration.amount
    //Approve IHimalayaMigrator to pull funds
    (IHimalayaMigrator.Migration memory migration, uint8 v, bytes32 r, bytes32 s) =
      abi.decode(callData, (IHimalayaMigrator.Migration, uint8, bytes32, bytes32));

    migration.assetDest.safeApprove(migration.himalaya, migration.amount);

    //Handle inbound
    //TODO this call should be wrapped in a try-catch.
    // If catch emit an event and move the funds to a seperate contract and make them claimable by the user.
    // perhaps a FujiV2 `Borrowingvault.deposit()`
    IHimalayaMigrator(migration.himalaya).receiveXMigration(callData);

    return abi.encode(transferId);
  }

  function xCall(IHimalayaMigrator.Migration memory migration)
    external
    onlyAllowedMigrator
    returns (bytes32 transferId)
  {
    //TODO decide on token is not "bridgeable" by connext

    //Pull funds from IHimalayaMigrator
    migration.assetOrigin.safeTransferFrom(msg.sender, address(this), migration.amount);

    //Approve connext to pull funds
    migration.assetOrigin.safeApprove(address(connext), migration.amount);

    //TODO check migration struct parameters are secure and correct - implement with permits
    transferId = connext.xcall(
      // _destination: Domain ID of the destination chain
      domainIds[migration.toChain],
      // _to: address of the target contract
      migration.himalaya,
      // _asset: address of the token contract
      address(migration.assetOrigin),
      // _delegate: address that has rights to update the original slippage tolerance
      // by calling Connext's forceUpdateSlippage function
      migration.himalaya,
      // _amount: amount of tokens to transfer
      migration.amount,
      // _slippage: can be anything between 0-10000 because
      // the maximum amount of slippage the user will accept in BPS, 30 == 0.3%
      migration.slippage,
      // _callData: data to be decoded and executed on the destination chain
      abi.encode(migration)
    );
  }

  function setHimalayaConnext(
    uint32 domainId,
    address himalayaConnext,
    bool active
  )
    external
    onlyTimelock
  {
    if (active) {
      himalayaConnexts[domainId] = himalayaConnext;
    } else {
      himalayaConnexts[domainId] = address(0);
    }
  }

  function setMigrator(address migrator, bool active) external onlyTimelock {
    allowedMigrator[migrator] = active;
  }

  function setDomainIds(
    uint256[] memory chainIds_,
    uint32[] memory domainIds_
  )
    external
    onlyTimelock
  {
    if (chainIds_.length != domainIds_.length || domainIds_.length == 0) {
      revert HimalayaConnext__setDomainIds_invalidInput();
    }
    for (uint256 i = 0; i < chainIds_.length; i++) {
      domainIds[chainIds_[i]] = domainIds_[i];
    }
  }

  //TODO Add bumpTransfer refer to:
  // https://github.com/Fujicracy/fuji-v2/blob/ace943c1c69e896ad3b06f3c16dd02c3c59be2d1/packages/protocol/src/routers/ConnextRouter.sol#L448-L456
}
