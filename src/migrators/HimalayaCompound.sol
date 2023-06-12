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
import {CompoundV2} from "../integrations/CompoundV2.sol";
import {CompoundV3} from "../integrations/CompoundV3.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IConnext, IXReceiver} from "@fuji-v2/src/interfaces/connext/IConnext.sol";

contract HimalayaCompound is IHimalayaMigrator, CompoundV2, CompoundV3, IXReceiver {
  using SafeERC20 for IERC20;

  mapping(address => bool) public isMarketV2;
  mapping(address => bool) public isMarketV3;

  IConnext public immutable connext;

  constructor(address _connext) {
    connext = IConnext(_connext);

    isMarketV2[0xe65cdB6479BaC1e22340E4E755fAE7E509EcD06c] = true; //cAAVE
    isMarketV2[0x6C8c6b02E7b2BE14d4fA6022Dfd6d75921D90E4E] = true; //cBAT
    isMarketV2[0x70e36f6BF80a52b3B46b3aF8e106CC0ed743E8e4] = true; //cCOMP
    isMarketV2[0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643] = true; //cDAI
    isMarketV2[0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5] = true; //cETH
    isMarketV2[0x7713DD9Ca933848F6819F38B8352D9A15EA73F67] = true; //cFEI
    isMarketV2[0xFAce851a4921ce59e912d19329929CE6da6EB0c7] = true; //cLINK
    isMarketV2[0x95b4eF2869eBD94BEb4eEE400a99824BF5DC325b] = true; //cMKR
    isMarketV2[0x158079Ee67Fce2f58472A96584A73C7Ab9AC95c1] = true; //cREP
    isMarketV2[0xF5DCe57282A584D2746FaF1593d3121Fcac444dC] = true; //cSAI
    isMarketV2[0x4B0181102A0112A2ef11AbEE5563bb4a3176c9d7] = true; //cSUSHI
    isMarketV2[0x12392F67bdf24faE0AF363c24aC620a2f67DAd86] = true; //cTUSD
    isMarketV2[0x35A18000230DA775CAc24873d00Ff85BccdeD550] = true; //cUNI
    isMarketV2[0x39AA39c021dfbaE8faC545936693aC917d5E7563] = true; //cUSDC
    isMarketV2[0x041171993284df560249B57358F931D9eB7b925D] = true; //cUSDP
    isMarketV2[0xf650C3d88D12dB855b8bf7D11Be6C55A4e07dCC9] = true; //cUSDT
    isMarketV2[0xC11b1268C1A384e55C48c2391d8d480264A3A7F4] = true; //cWBTC
    isMarketV2[0xccF4429DB6322D5C611ee964527D42E5d685DD6a] = true; //cWBTC2
    isMarketV2[0x80a2AE356fc9ef4305676f7a3E2Ed04e12C33946] = true; //cYFI
    isMarketV2[0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643] = true; //cZRX

    isMarketV3[0xc3d688B66703497DAA19211EEdff47f25384cdc3] = true; //mainnet cUSDCV3
    isMarketV3[0xA17581A9E3356d9A858b789D68B4d866e593aE94] = true; //mainnet cWETHV3
    isMarketV3[0xF25212E676D1F7F89Cd72fFEe66158f541246445] = true; //polygon cUSDCV3
    isMarketV3[0xA5EDBDD9646f8dFF606d7448e414884C7d905dCA] = true; //arbitrum cUSDCV3
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
   * @dev It does not perform authentication of the calling address. As a result of that,
   * all txns go through Connext's fast path.
   * If `xBundle` fails internally, this contract will send the received funds to {ConnextHandler}.
   *
   * Requirements:
   * - `calldata` parameter must be encoded with the following structure:
   *     > abi.encode(Action[] actions, bytes[] args)
   * - actions: array of serialized actions to execute from available enum {IRouter.Action}.
   * - args: array of encoded arguments according to each action. See {BaseRouter-internalBundle}.
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
    //TODO
    //decode calldata

    //Handle inbound
    receiveXMigration(callData);

    return "";
  }

  function beginXMigration(Migration memory migration) public returns (bytes32 transferId) {
    //TODO check parameters

    //Identify market
    if (isMarketV2[migration.fromMarket]) {
      _handleOutboundFromV2(
        migration.toChain, migration.owner, migration.fromMarket, migration.asset, migration.amount
      );
    } else if (isMarketV3[migration.fromMarket]) {
      _handleOutboundFromV3(
        migration.toChain, migration.owner, migration.fromMarket, migration.asset, migration.amount
      );
    } else {
      revert("Market not supported");
    }

    transferId = connext.xcall(
      // _destination: Domain ID of the destination chain
      uint32(migration.toChain),
      // _to: address of the target contract
      migration.himalaya,
      // _asset: address of the token contract
      migration.asset,
      // _delegate: address that has rights to update the original slippage tolerance
      // by calling Connext's forceUpdateSlippage function
      migration.himalaya,
      // _amount: amount of tokens to transfer
      migration.amount,
      // _slippage: can be anything between 0-10000 because
      // the maximum amount of slippage the user will accept in BPS, 30 == 0.3%
      30, //TODO implement this
      // _callData: empty because we're only sending funds
      "" //TODO implement this
    );
  }

  function receiveXMigration(bytes memory data) public returns (bool) {
    Migration memory migration = abi.decode(data, (Migration));
    //TODO check parameters

    if (isMarketV3[migration.toMarket]) {
      _handleInboundToV3(
        migration.owner,
        migration.toMarket,
        migration.asset,
        migration.amount,
        migration.debtAsset,
        migration.debtAmount
      );
    } else {
      revert("Market not supported");
    }

    return true;
  }

  function _handleOutboundFromV2(
    uint128 toChain,
    address owner,
    address fromMarket,
    address asset,
    uint256 amount
  )
    internal
    returns (bool)
  {
    //Pull cTokens from user
    uint256 cTokenBalance = IERC20(fromMarket).balanceOf(owner);
    SafeERC20.safeTransferFrom(IERC20(fromMarket), owner, address(this), cTokenBalance);

    //Withdraw funds from V2
    withdrawV2(amount, asset, fromMarket);

    //TODO bridge funds to V3 on destination chain with call to deposit

    return true;
  }

  function _handleOutboundFromV3(
    uint128 toChain,
    address owner,
    address fromMarket,
    address asset,
    uint256 amount
  )
    internal
    returns (bool)
  {
    return true;
  }

  function _handleInboundToV3(
    address owner,
    address toMarket,
    address asset,
    uint256 amount,
    address debtAsset,
    uint256 debtAmount
  )
    internal
    returns (bool)
  {
    IERC20(asset).safeIncreaseAllowance(toMarket, amount);
    depositV3(owner, amount, asset, toMarket);

    borrowV3(owner, debtAmount, debtAsset, toMarket);

    return true;
  }
}
