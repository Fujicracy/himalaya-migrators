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
import {HimalayaCompoundUtils} from "../HimalayaCompoundUtils.t.sol";
import {IXReceiver} from "@fuji-v2/src/interfaces/connext/IConnext.sol";

/**
 * @dev This contract tests the integration of CompoundV2 and CompoundV3.
 */
contract HimalayaCompoundUnitTests is HimalayaCompoundUtils {
  function setUp() public {
    vm.createSelectFork("mainnet");
    compoundV2 = new CompoundV2();
    compoundV3 = new CompoundV3();

    himalayaCompound = new HimalayaCompound(CONNEXT_MAINNET);

    setLabels();
  }

  function test_handleOutboundFromV2ToV3() public {
    deal(WETH, ALICE, 100e18);
    assertEq(IERC20(WETH).balanceOf(ALICE), 100e18);

    //Deposit 100 WETH into CompoundV2
    vm.startPrank(ALICE);
    _utils_depositV2_mainnet(100e18, WETH);
    assertApproxEqAbs(compoundV2.getDepositBalanceV2(ALICE, address(cETHV2)), 100e18, 100e18 / 10);
    assertEq(IERC20(WETH).balanceOf(address(compoundV2)), 0);

    //Migrate 100 WETH deposit position from CompoundV2 to CompoundV3
    uint256 balanceCTokenV2 = cETHV2.balanceOf(ALICE);

    IHimalayaMigrator.Migration memory migration;
    migration.owner = ALICE;
    migration.fromMarket = address(cETHV2);
    migration.toMarket = cWETHV3;
    migration.asset = WETH;
    migration.amount = 100e18;
    migration.debtAsset = address(0);
    migration.debtAmount = 0;
    migration.fromChain = 1;
    migration.toChain = 127; //Polygon
    migration.himalaya = address(0); //TODO

    //approve himalayaCompound to pull cTokens
    cETHV2.approve(address(himalayaCompound), balanceCTokenV2);

    himalayaCompound.beginXMigration(migration);
    assertEq(IERC20(WETH).balanceOf(address(himalayaCompound)), 0);
    assertEq(compoundV2.getDepositBalanceV2(ALICE, address(cETHV2)), 0);
  }

  function test_handleOutboundFromV3ToV3() public {
    deal(WBTC, ALICE, 100e18);
    assertEq(IERC20(WBTC).balanceOf(ALICE), 100e18);

    //Deposit 100 WETH into CompoundV3 on mainnet
    vm.startPrank(ALICE);
    _utils_depositV3(100e18, WBTC, cUSDCV3);
    assertApproxEqAbs(compoundV3.getDepositBalanceV3(ALICE, WBTC, cUSDCV3), 100e18, 100e18 / 10);

    //Migrate 100 WETH deposit position from CompoundV3 on mainnet to CompoundV3 on other chain
    IHimalayaMigrator.Migration memory migration;
    migration.owner = ALICE;
    migration.fromMarket = cUSDCV3;
    migration.toMarket = cUSDCV3_Polygon;
    migration.asset = WBTC;
    migration.amount = 100e18;
    migration.debtAsset = USDC;
    migration.debtAmount = 100e6;
    migration.fromChain = 1;
    migration.toChain = 127; //Polygon
    migration.himalaya = address(0); //TODO

    //approve himalayaCompound as operator on V3
    ICompoundV3(migration.fromMarket).allow(address(himalayaCompound), true);

    himalayaCompound.beginXMigration(migration);
    assertEq(IERC20(WETH).balanceOf(address(himalayaCompound)), 0);
    assertEq(compoundV3.getDepositBalanceV3(ALICE, WETH, cWETHV3), 0);
  }

  function test_handleInboundToV3() public {
    //Migration from 100 WETH deposit position from CompoundV2 on other chain to CompoundV3 on mainnet
    IHimalayaMigrator.Migration memory migration;
    migration.owner = ALICE;
    migration.fromMarket = cUSDCV3_Polygon;
    migration.toMarket = cUSDCV3;
    migration.asset = WBTC;
    migration.amount = AMOUNT_SUPPLY_WBTC;
    migration.debtAsset = USDC;
    migration.debtAmount = AMOUNT_BORROW_USDC;
    migration.fromChain = 127;
    migration.toChain = 1; //Polygon
    migration.himalaya = address(himalayaCompound);

    //approve himalayaCompound as operator on V3
    vm.startPrank(ALICE);
    ICompoundV3(migration.toMarket).allow(address(himalayaCompound), true);
    vm.stopPrank();

    //mock connext behaviour by sending funds directly to himalayaCompound
    deal(WBTC, address(himalayaCompound), AMOUNT_SUPPLY_WBTC);

    bytes memory data = abi.encode(migration);
    IXReceiver(address(himalayaCompound)).xReceive(
      "", migration.amount, migration.asset, ALICE, uint32(migration.fromChain), data
    );

    assertEq(IERC20(USDC).balanceOf(ALICE), AMOUNT_BORROW_USDC);
    assertEq(compoundV3.getDepositBalanceV3(ALICE, WBTC, cUSDCV3), AMOUNT_SUPPLY_WBTC);
  }
}
