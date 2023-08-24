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
import {IHimalayaConnext} from "../../src/interfaces/IHimalayaConnext.sol";

/**
 * @dev This contract tests the cross chain migration using the HimalayaCompound contract.
 */
contract HimalayaCompoundUnitTests is Utils {
  function setUp() public {
    vm.createSelectFork("mainnet");
    compoundV2 = new CompoundV2();
    compoundV3 = new CompoundV3();

    setTimelock();
    himalayaConnext = new HimalayaConnext(CONNEXT_MAINNET, address(chief));
    himalayaCompound = new HimalayaCompound(
            address(himalayaConnext),
            address(chief)
        );

    bytes memory executionCall =
      abi.encodeWithSelector(IHimalayaConnext.setMigrator.selector, address(himalayaCompound), true);
    _callWithTimelock(address(himalayaConnext), executionCall);

    uint32[] memory domainIds = new uint32[](3);
    uint32[] memory ids = new uint32[](3);
    //mainnet
    ids[0] = 1;
    domainIds[0] = 6648936;
    //polygon
    ids[1] = 137;
    domainIds[1] = 1886350457;
    //arbitrum
    ids[2] = 42161;
    domainIds[2] = 1634886255;
    executionCall = abi.encodeWithSelector(IHimalayaConnext.setDomainIds.selector, ids, domainIds);
    _callWithTimelock(address(himalayaConnext), executionCall);

    setLabels();
    setLabelsCompound();
    addMarketsDestChain_mainnet();
    addMarkets_mainnet();
  }

  function test_handleOutboundFromV2ToV3() public {
    deal(WETH, ALICE, AMOUNT_SUPPLY_WETH);
    assertEq(IERC20(WETH).balanceOf(ALICE), AMOUNT_SUPPLY_WETH);

    //Deposit WETH into CompoundV2
    vm.startPrank(ALICE);
    _utils_depositV2_mainnet(AMOUNT_SUPPLY_WETH, WETH);

    vm.warp(block.timestamp + 13 seconds);
    vm.roll(block.number + 1);

    assertApproxEqAbs(
      compoundV2.getDepositBalanceV2(ALICE, address(cETHV2)),
      AMOUNT_SUPPLY_WETH,
      AMOUNT_SUPPLY_WETH / 10
    );
    assertGt(compoundV2.getDepositBalanceV2(ALICE, address(cETHV2)), AMOUNT_SUPPLY_WETH);
    assertEq(IERC20(WETH).balanceOf(address(compoundV2)), 0);

    //Migrate WETH deposit position from CompoundV2 to CompoundV3
    uint256 balanceCTokenV2 = cETHV2.balanceOf(ALICE);

    IHimalayaMigrator.Migration memory migration;
    migration.owner = ALICE;
    migration.fromMarket = address(cETHV2);
    migration.toMarket = cUSDCV3_Polygon;
    migration.assetOrigin = IERC20(WETH);
    migration.assetDest = IERC20(WETH_Polygon);
    migration.amount = compoundV2.getDepositBalanceV2(ALICE, address(cETHV2));
    migration.debtAssetOrigin = IERC20(address(0));
    migration.debtAssetDest = IERC20(address(0));
    migration.debtAmount = 0;
    migration.toChain = 137; //Polygon
    migration.himalaya = address(himalayaConnext_Polygon);
    migration.slippage = 30;

    //approve himalayaCompound to pull cTokens
    cETHV2.approve(address(himalayaCompound), balanceCTokenV2);

    himalayaCompound.beginXMigration(migration);
    assertEq(IERC20(WETH).balanceOf(address(himalayaCompound)), 0);
    assertEq(compoundV2.getDepositBalanceV2(ALICE, address(cETHV2)), 0);
  }

  function test_handleOutboundWithBorrowFromV2ToV3() public {
    deal(WETH, ALICE, AMOUNT_SUPPLY_WETH);
    assertEq(IERC20(WETH).balanceOf(ALICE), AMOUNT_SUPPLY_WETH);

    //Deposit WETH into CompoundV2
    vm.startPrank(ALICE);
    _utils_depositV2_mainnet(AMOUNT_SUPPLY_WETH, WETH);
    _utils_borrowV2_mainnet(AMOUNT_BORROW_USDC, address(cUSDCV2));

    vm.warp(block.timestamp + 13 seconds);
    vm.roll(block.number + 1);

    assertApproxEqAbs(
      compoundV2.getDepositBalanceV2(ALICE, address(cETHV2)),
      AMOUNT_SUPPLY_WETH,
      AMOUNT_SUPPLY_WETH / 10
    );

    assertApproxEqAbs(
      compoundV2.getBorrowBalanceV2(ALICE, address(cUSDCV2)),
      AMOUNT_BORROW_USDC,
      AMOUNT_BORROW_USDC / 10
    );
    assertEq(IERC20(WETH).balanceOf(address(compoundV2)), 0);

    assertGt(compoundV2.getBorrowBalanceV2(ALICE, address(cUSDCV2)), AMOUNT_BORROW_USDC);
    assertEq(IERC20(USDC).balanceOf(address(compoundV2)), 0);

    //Migrate WETH deposit position from CompoundV2 to CompoundV3
    uint256 balanceCTokenV2 = cETHV2.balanceOf(ALICE);

    IHimalayaMigrator.Migration memory migration;
    migration.owner = ALICE;
    migration.fromMarket = address(cETHV2);
    migration.toMarket = cUSDCV3_Polygon;
    migration.assetOrigin = IERC20(WETH);
    migration.assetDest = IERC20(WETH_Polygon);
    migration.amount = compoundV2.getDepositBalanceV2(ALICE, address(cETHV2));
    migration.fromDebtMarket = address(cUSDCV2);
    migration.debtAssetOrigin = IERC20(USDC);
    migration.debtAssetDest = IERC20(address(USDC_Polygon));
    migration.debtAmount = compoundV2.getBorrowBalanceV2(ALICE, address(cUSDCV2));
    migration.toChain = 137; //Polygon
    migration.himalaya = address(himalayaConnext_Polygon);
    migration.slippage = 30;

    //approve himalayaCompound to pull cTokens
    cETHV2.approve(address(himalayaCompound), balanceCTokenV2);
    //approve himalayaCompound to pull USDC to repay borrow
    IERC20(USDC).approve(address(himalayaCompound), migration.debtAmount);

    deal(USDC, ALICE, compoundV2.getBorrowBalanceV2(ALICE, address(cUSDCV2)));

    himalayaCompound.beginXMigration(migration);
    assertEq(IERC20(WETH).balanceOf(address(himalayaCompound)), 0);
    assertEq(compoundV2.getDepositBalanceV2(ALICE, address(cETHV2)), 0);
    assertEq(IERC20(USDC).balanceOf(address(himalayaCompound)), 0);
    assertEq(compoundV2.getBorrowBalanceV2(ALICE, address(cUSDCV2)), 0);
  }

  function test_handleOutboundFromV3ToV3() public {
    deal(WETH, ALICE, AMOUNT_SUPPLY_WETH);
    assertEq(IERC20(WETH).balanceOf(ALICE), AMOUNT_SUPPLY_WETH);

    //Deposit WETH into CompoundV3 on mainnet
    vm.startPrank(ALICE);
    IERC20(WETH).approve(address(cUSDCV3), AMOUNT_SUPPLY_WETH);
    _utils_depositV3(AMOUNT_SUPPLY_WETH, WETH, cUSDCV3);
    assertApproxEqAbs(
      compoundV3.getDepositBalanceV3(ALICE, WETH, cUSDCV3),
      AMOUNT_SUPPLY_WETH,
      AMOUNT_SUPPLY_WETH / 10
    );

    //Migrate WETH deposit position from CompoundV3 on mainnet to CompoundV3 on other chain
    IHimalayaMigrator.Migration memory migration;
    migration.owner = ALICE;
    migration.fromMarket = cUSDCV3;
    migration.toMarket = cUSDCV3_Polygon;
    migration.assetOrigin = IERC20(WETH);
    migration.assetDest = IERC20(WETH_Polygon);
    migration.amount = compoundV3.getDepositBalanceV3(ALICE, WETH, cUSDCV3);
    migration.debtAssetOrigin = IERC20(USDC);
    migration.debtAssetDest = IERC20(USDC_Polygon);
    migration.debtAmount = 0;
    migration.toChain = 137; //Polygon
    migration.himalaya = address(himalayaConnext_Polygon);
    migration.slippage = 30;

    //approve himalayaCompound as operator on V3 originChain
    ICompoundV3(migration.fromMarket).allow(address(himalayaCompound), true);

    himalayaCompound.beginXMigration(migration);
    assertEq(IERC20(WETH).balanceOf(address(himalayaCompound)), 0);
    assertEq(compoundV3.getDepositBalanceV3(ALICE, WETH, cUSDCV3), 0);
  }

  function test_handleOutboundWithBorrowFromV3ToV3() public {
    deal(WETH, ALICE, AMOUNT_SUPPLY_WETH);
    assertEq(IERC20(WETH).balanceOf(ALICE), AMOUNT_SUPPLY_WETH);
    deal(USDC, ALICE, AMOUNT_BORROW_USDC * 10);
    assertEq(IERC20(USDC).balanceOf(ALICE), AMOUNT_BORROW_USDC * 10);

    //Deposit WETH into CompoundV3 on mainnet
    vm.startPrank(ALICE);
    IERC20(WETH).approve(address(cUSDCV3), AMOUNT_SUPPLY_WETH);
    _utils_depositV3(AMOUNT_SUPPLY_WETH, WETH, cUSDCV3);
    assertApproxEqAbs(
      compoundV3.getDepositBalanceV3(ALICE, WETH, cUSDCV3),
      AMOUNT_SUPPLY_WETH,
      AMOUNT_SUPPLY_WETH / 10
    );
    _utils_borrowV3(AMOUNT_BORROW_USDC, USDC, cUSDCV3);
    assertApproxEqAbs(
      compoundV3.getBorrowBalanceV3(ALICE, USDC, cUSDCV3),
      AMOUNT_BORROW_USDC,
      AMOUNT_BORROW_USDC / 10
    );

    for (uint256 i = 0; i < 10; i++) {
      vm.warp(block.timestamp + 13 seconds);
      vm.roll(block.number + 1);
    }

    //Migrate WETH deposit position from CompoundV3 on mainnet to CompoundV3 on other chain
    IHimalayaMigrator.Migration memory migration;
    migration.owner = ALICE;
    migration.fromMarket = cUSDCV3;
    migration.toMarket = cUSDCV3_Polygon;
    migration.assetOrigin = IERC20(WETH);
    migration.assetDest = IERC20(WETH_Polygon);
    migration.amount = compoundV3.getDepositBalanceV3(ALICE, WETH, cUSDCV3);
    migration.fromDebtMarket = cUSDCV3;
    migration.debtAssetOrigin = IERC20(USDC);
    migration.debtAssetDest = IERC20(USDC_Polygon);
    migration.debtAmount = compoundV3.getBorrowBalanceV3(ALICE, USDC, cUSDCV3);
    migration.toChain = 137; //Polygon
    migration.himalaya = address(himalayaConnext_Polygon);
    migration.slippage = 30;

    //approve himalayaCompound as operator on V3 originChain
    ICompoundV3(migration.fromMarket).allow(address(himalayaCompound), true);
    //approve market to pull debtAsset to payback debt
    //debt may have grown due to interest
    IERC20(USDC).approve(address(cUSDCV3), AMOUNT_BORROW_USDC * 10);

    himalayaCompound.beginXMigration(migration);
    assertEq(IERC20(WETH).balanceOf(address(himalayaCompound)), 0);
    assertEq(compoundV3.getDepositBalanceV3(ALICE, WETH, cUSDCV3), 0);
    assertEq(IERC20(USDC).balanceOf(address(himalayaCompound)), 0);
    assertEq(compoundV3.getBorrowBalanceV3(ALICE, USDC, cUSDCV3), 0);
  }

  function test_handleOutboundWithBorrowFromV3ToV3WithArbitraryAmounts(
    uint256 collateralAmount,
    uint256 debtAmount
  )
    public
  {
    vm.assume(collateralAmount > 1e14);
    deal(WETH, ALICE, AMOUNT_SUPPLY_WETH);
    assertEq(IERC20(WETH).balanceOf(ALICE), AMOUNT_SUPPLY_WETH);

    vm.startPrank(ALICE);
    IERC20(WETH).approve(address(cUSDCV3), AMOUNT_SUPPLY_WETH);
    _utils_depositV3(AMOUNT_SUPPLY_WETH, WETH, cUSDCV3);
    assertApproxEqAbs(
      compoundV3.getDepositBalanceV3(ALICE, WETH, cUSDCV3),
      AMOUNT_SUPPLY_WETH,
      AMOUNT_SUPPLY_WETH / 10
    );
    _utils_borrowV3(AMOUNT_BORROW_USDC, USDC, cUSDCV3);
    assertApproxEqAbs(
      compoundV3.getBorrowBalanceV3(ALICE, USDC, cUSDCV3),
      AMOUNT_BORROW_USDC,
      AMOUNT_BORROW_USDC / 10
    );

    for (uint256 i = 0; i < 10; i++) {
      vm.warp(block.timestamp + 13 seconds);
      vm.roll(block.number + 1);
    }

    IHimalayaMigrator.Migration memory migration;
    migration.owner = ALICE;
    migration.fromMarket = cUSDCV3;
    migration.toMarket = cUSDCV3_Polygon;
    migration.assetOrigin = IERC20(WETH);
    migration.assetDest = IERC20(WETH_Polygon);
    migration.amount = collateralAmount;
    migration.fromDebtMarket = cUSDCV3;
    migration.debtAssetOrigin = IERC20(USDC);
    migration.debtAssetDest = IERC20(USDC_Polygon);
    migration.debtAmount = debtAmount;
    migration.toChain = 137; //Polygon
    migration.himalaya = address(himalayaConnext_Polygon);
    migration.slippage = 30;

    //approve himalayaCompound as operator on V3 originChain
    ICompoundV3(migration.fromMarket).allow(address(himalayaCompound), true);
    IERC20(USDC).approve(address(cUSDCV3), debtAmount);

    vm.stopPrank();

    uint256 userDepositAmount = compoundV3.getDepositBalanceV3(ALICE, WETH, cUSDCV3);
    uint256 userDebtAmount = compoundV3.getBorrowBalanceV3(ALICE, USDC, cUSDCV3);
    //case 1: user tries to withdraw/payback more than they have/owe
    if (collateralAmount > userDepositAmount || debtAmount > userDebtAmount) {
      vm.expectRevert(
        HimalayaCompound.HimalayaCompound__handleOutboundFromV3_invalidAmount.selector
      );
      vm.prank(ALICE);
      himalayaCompound.beginXMigration(migration);
    }
    //case 2: no amounts to migrate
    else if (collateralAmount == 0 && debtAmount == 0) {
      vm.expectRevert(
        HimalayaCompound.HimalayaCompound__handleOutboundFromV3_invalidAmount.selector
      );
      vm.prank(ALICE);
      himalayaCompound.beginXMigration(migration);
    }
    //case 3: user tries to make his position unhealthy
    else if (
      !_utils_positionIsHealthy(
        cUSDCV3, WETH, USDC, userDepositAmount - collateralAmount, userDebtAmount - debtAmount
      )
    ) {
      vm.expectRevert();
      vm.prank(ALICE);
      himalayaCompound.beginXMigration(migration);
    } else {
      vm.prank(ALICE);
      himalayaCompound.beginXMigration(migration);
      assertEq(IERC20(WETH).balanceOf(address(himalayaCompound)), 0);
      assertEq(
        compoundV3.getDepositBalanceV3(ALICE, WETH, cUSDCV3), userDepositAmount - collateralAmount
      );
      assertEq(IERC20(USDC).balanceOf(address(himalayaCompound)), 0);
      assertApproxEqAbs(
        compoundV3.getBorrowBalanceV3(ALICE, USDC, cUSDCV3), userDebtAmount - debtAmount, 1
      );
    }
  }

  function test_tryHandleInboundToV3WithoutHimalayaConnext() public {
    //Migration from WETH deposit position from CompoundV2 on other chain to CompoundV3 on mainnet
    IHimalayaMigrator.Migration memory migration;
    migration.owner = ALICE;
    migration.fromMarket = cUSDCV3_Polygon;
    migration.toMarket = cUSDCV3;
    migration.assetOrigin = IERC20(WETH_Polygon);
    migration.assetDest = IERC20(WETH);
    migration.amount = AMOUNT_SUPPLY_WETH;
    migration.debtAssetOrigin = IERC20(USDC_Polygon);
    migration.debtAssetDest = IERC20(USDC);
    migration.debtAmount = AMOUNT_BORROW_USDC;
    migration.toChain = 1; //Mainnet
    migration.himalaya = address(himalayaCompound);
    migration.slippage = 30;

    //approve himalayaCompound as operator on V3
    vm.startPrank(ALICE);
    ICompoundV3(migration.toMarket).allow(address(himalayaCompound), true);
    vm.stopPrank();

    //mock connext and himalayaConnext behaviour by dealing and approving
    deal(WETH, address(this), AMOUNT_SUPPLY_WETH);
    //approve
    IERC20(WETH).approve(address(himalayaCompound), AMOUNT_SUPPLY_WETH);

    bytes memory data = abi.encode(migration);
    vm.expectRevert(HimalayaCompound.HimalayaCompound__onlyHimalayaConnext_notAuthorized.selector);
    himalayaCompound.receiveXMigration(data);
  }

  function test_handleInboundToV3WithHimalayaConnext() public {
    //Migration from WETH deposit position from CompoundV2 on other chain to CompoundV3 on mainnet
    IHimalayaMigrator.Migration memory migration;
    migration.owner = ALICE;
    migration.fromMarket = cUSDCV3_Polygon;
    migration.toMarket = cUSDCV3;
    migration.assetOrigin = IERC20(WETH_Polygon);
    migration.assetDest = IERC20(WETH);
    migration.amount = AMOUNT_SUPPLY_WETH;
    migration.debtAssetOrigin = IERC20(USDC_Polygon);
    migration.debtAssetDest = IERC20(USDC);
    migration.debtAmount = AMOUNT_BORROW_USDC;
    migration.toChain = 1; //Mainnet
    migration.himalaya = address(himalayaCompound);
    migration.slippage = 30;

    //approve himalayaCompound as operator on V3
    vm.startPrank(ALICE);
    ICompoundV3(migration.toMarket).allow(address(himalayaCompound), true);
    vm.stopPrank();

    //mock connext behaviour by dealing and approving
    deal(WETH, address(himalayaConnext), AMOUNT_SUPPLY_WETH);

    bytes memory data = abi.encode(migration);
    himalayaConnext.xReceive(
      0, migration.amount, address(migration.assetDest), migration.owner, POLYGON_DOMAIN, data
    );

    assertEq(IERC20(USDC).balanceOf(ALICE), AMOUNT_BORROW_USDC);
    assertEq(compoundV3.getDepositBalanceV3(ALICE, WETH, cUSDCV3), AMOUNT_SUPPLY_WETH);
    assertEq(compoundV3.getBorrowBalanceV3(ALICE, USDC, cUSDCV3), AMOUNT_BORROW_USDC);
  }

  function test_handleInboundToV3WithHimalayaConnextWithInvalidAmount() public {
    //Migration from 0 WETH deposit position from other chain to CompoundV3 on mainnet
    IHimalayaMigrator.Migration memory migration;
    migration.owner = ALICE;
    migration.fromMarket = cUSDCV3_Polygon;
    migration.toMarket = cUSDCV3;
    migration.assetOrigin = IERC20(WETH_Polygon);
    migration.assetDest = IERC20(WETH);
    migration.amount = 0;
    migration.debtAssetOrigin = IERC20(USDC_Polygon);
    migration.debtAssetDest = IERC20(USDC);
    migration.debtAmount = AMOUNT_BORROW_USDC;
    migration.toChain = 1; //Mainnet
    migration.himalaya = address(himalayaCompound);
    migration.slippage = 30;

    //approve himalayaCompound as operator on V3
    vm.startPrank(ALICE);
    ICompoundV3(migration.toMarket).allow(address(himalayaCompound), true);
    vm.stopPrank();

    bytes memory data = abi.encode(migration);
    vm.expectEmit(true, true, true, true);
    emit BorrowFailed(migration.toMarket, address(migration.debtAssetDest), migration.debtAmount);
    himalayaConnext.xReceive(
      0, migration.amount, address(migration.assetDest), migration.owner, MAINNET_DOMAIN, data
    );

    assertEq(IERC20(USDC).balanceOf(ALICE), 0);
    assertEq(compoundV3.getDepositBalanceV3(ALICE, WETH, cUSDCV3), 0);
    assertEq(compoundV3.getBorrowBalanceV3(ALICE, USDC, cUSDCV3), 0);
  }
}
