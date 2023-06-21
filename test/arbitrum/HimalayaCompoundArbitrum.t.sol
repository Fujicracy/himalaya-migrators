// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {CompoundV2} from "../../src/integrations/CompoundV2.sol";
import {CompoundV3} from "../../src/integrations/CompoundV3.sol";
import {ICETH} from "@fuji-v2/src/interfaces/compoundV2/ICETH.sol";
import {ICERC20} from "@fuji-v2/src/interfaces/compoundV2/ICERC20.sol";
import {IComptroller} from "@fuji-v2/src/interfaces/compoundV2/IComptroller.sol";
import {IWETH9} from "@fuji-v2/src/abstracts/WETH9.sol";
import {LibCompoundV2} from "@fuji-v2/src/libraries/LibCompoundV2.sol";
import {ICToken} from "@fuji-v2/src/interfaces/compoundV2/ICToken.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IHimalayaMigrator} from "../../src/interfaces/IHimalayaMigrator.sol";
import {HimalayaCompound} from "../../src/migrators/HimalayaCompound.sol";
import {ICompoundV3} from "@fuji-v2/src/interfaces/compoundV3/ICompoundV3.sol";
import {IXReceiver} from "@fuji-v2/src/interfaces/connext/IConnext.sol";
import {HimalayaCompoundUtils} from "../HimalayaCompoundUtils.t.sol";
import {ConnextUtils} from "../ConnextUtils.t.sol";
import {Utils} from "../Utils.t.sol";
import {HimalayaConnext} from "../../src/migrators/HimalayaConnext.sol";

/**
 * @dev This contract tests the cross chain migration using the HimalayaCompound contract.
 */
contract HimalayaCompoundArbitrumUnitTests is HimalayaCompoundUtils, ConnextUtils, Utils {
  function setUp() public {
    vm.createSelectFork("arbitrum");
    compoundV2 = new CompoundV2();
    compoundV3 = new CompoundV3();

    himalayaConnext = new HimalayaConnext(CONNEXT_ARBITRUM);
    himalayaCompound = new HimalayaCompound(address(himalayaConnext));

    setLabels();
    setLabelsCompound();
    addMarketsDestChain_arbitrum();
    addMarkets_arbitrum();
  }

  function test_handleOutboundFromV3ToV3() public {
    deal(WETH_Arbitrum, ALICE, AMOUNT_SUPPLY_WETH);
    assertEq(IERC20(WETH_Arbitrum).balanceOf(ALICE), AMOUNT_SUPPLY_WETH);

    //Deposit 100 WETH into CompoundV3 on arbitrum
    vm.startPrank(ALICE);
    IERC20(WETH_Arbitrum).approve(address(cUSDCV3_Arbitrum), AMOUNT_SUPPLY_WETH);
    _utils_depositV3(AMOUNT_SUPPLY_WETH, WETH_Arbitrum, cUSDCV3_Arbitrum);
    assertApproxEqAbs(
      compoundV3.getDepositBalanceV3(ALICE, WETH_Arbitrum, cUSDCV3_Arbitrum),
      AMOUNT_SUPPLY_WETH,
      AMOUNT_SUPPLY_WETH / 10
    );

    //Migrate 100 WETH deposit position from CompoundV3 on arbitrum to CompoundV3 on other chain
    IHimalayaMigrator.Migration memory migration;
    migration.owner = ALICE;
    migration.fromMarket = cUSDCV3_Arbitrum;
    migration.toMarket = cUSDCV3_Polygon;
    migration.assetOrigin = IERC20(WETH_Arbitrum);
    migration.assetDest = IERC20(WETH_Polygon);
    migration.amount = AMOUNT_SUPPLY_WETH;
    migration.debtAssetOrigin = IERC20(USDC_Arbitrum);
    migration.debtAssetDest = IERC20(USDC_Polygon);
    // migration.debtAmount = AMOUNT_BORROW_USDC;//TODO add borrow before migration
    migration.debtAmount = 0;
    migration.fromChain = 42161; //Arbitrum
    migration.toChain = 137; //Polygon
    migration.himalaya = address(himalayaConnext_Polygon);

    //approve himalayaCompound as operator on V3 originChain
    ICompoundV3(migration.fromMarket).allow(address(himalayaCompound), true);

    himalayaCompound.beginXMigration(migration);
    assertEq(IERC20(WETH_Arbitrum).balanceOf(address(himalayaCompound)), 0);
    assertEq(compoundV3.getDepositBalanceV3(ALICE, WETH_Arbitrum, cUSDCV3_Arbitrum), 0);
  }

  function test_handleInboundToV3() public {
    //Migration from 100 WETH deposit position from CompoundV2 on other chain to CompoundV3 on arbitrum
    IHimalayaMigrator.Migration memory migration;
    migration.owner = ALICE;
    migration.fromMarket = cUSDCV3_Polygon;
    migration.toMarket = cUSDCV3_Arbitrum;
    migration.assetOrigin = IERC20(WETH_Polygon);
    migration.assetDest = IERC20(WETH_Arbitrum);
    migration.amount = AMOUNT_SUPPLY_WETH;
    migration.debtAssetOrigin = IERC20(USDC_Polygon);
    migration.debtAssetDest = IERC20(USDC_Arbitrum);
    migration.debtAmount = AMOUNT_BORROW_USDC;
    migration.fromChain = 137; //Polygon
    migration.toChain = 42161; //Arbitrum
    migration.himalaya = address(himalayaCompound);

    //approve himalayaCompound as operator on V3
    vm.startPrank(ALICE);
    ICompoundV3(migration.toMarket).allow(address(himalayaCompound), true);
    vm.stopPrank();

    //mock connext and himalayaConnext behaviour by dealing and approving
    deal(WETH_Arbitrum, address(this), AMOUNT_SUPPLY_WETH);
    //approve
    IERC20(WETH_Arbitrum).approve(address(himalayaCompound), AMOUNT_SUPPLY_WETH);

    bytes memory data = abi.encode(migration);
    himalayaCompound.receiveXMigration(data);

    assertEq(IERC20(USDC_Arbitrum).balanceOf(ALICE), AMOUNT_BORROW_USDC);
    assertEq(
      compoundV3.getDepositBalanceV3(ALICE, WETH_Arbitrum, cUSDCV3_Arbitrum), AMOUNT_SUPPLY_WETH
    );
  }

  function test_handleInboundToV3WithHimalayaConnext() public {
    //Migration from 100 WETH deposit position from CompoundV2 on other chain to CompoundV3 on arbitrum
    IHimalayaMigrator.Migration memory migration;
    migration.owner = ALICE;
    migration.fromMarket = cUSDCV3_Polygon;
    migration.toMarket = cUSDCV3_Arbitrum;
    migration.assetOrigin = IERC20(WETH_Polygon);
    migration.assetDest = IERC20(WETH_Arbitrum);
    migration.amount = AMOUNT_SUPPLY_WETH;
    migration.debtAssetOrigin = IERC20(USDC_Polygon);
    migration.debtAssetDest = IERC20(USDC_Arbitrum);
    migration.debtAmount = AMOUNT_BORROW_USDC;
    migration.fromChain = 137; //Polygon
    migration.toChain = 42161; //Arbitrum
    migration.himalaya = address(himalayaCompound);

    //approve himalayaCompound as operator on V3
    vm.startPrank(ALICE);
    ICompoundV3(migration.toMarket).allow(address(himalayaCompound), true);
    vm.stopPrank();

    //mock connext behaviour by dealing and approving
    deal(WETH_Arbitrum, address(himalayaConnext), AMOUNT_SUPPLY_WETH);

    bytes memory data = abi.encode(migration);
    himalayaConnext.xReceive(
      0, migration.amount, address(migration.assetDest), migration.owner, ARBITRUM_DOMAIN, data
    );

    assertEq(IERC20(USDC_Arbitrum).balanceOf(ALICE), AMOUNT_BORROW_USDC);
    assertEq(
      compoundV3.getDepositBalanceV3(ALICE, WETH_Arbitrum, cUSDCV3_Arbitrum), AMOUNT_SUPPLY_WETH
    );
  }
}
