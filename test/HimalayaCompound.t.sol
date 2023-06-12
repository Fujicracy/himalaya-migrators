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
import {IConnext, IXReceiver} from "@fuji-v2/src/interfaces/connext/IConnext.sol";

/**
 * @dev This contract tests the integration of CompoundV2 and CompoundV3.
 */
contract HimalayaCompoundUnitTests is Test {
  uint256 public constant ALICE_PK = 0xA;
  address public ALICE = vm.addr(ALICE_PK);

  address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
  address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

  CompoundV2 public compoundV2;
  CompoundV3 public compoundV3;

  IHimalayaMigrator public himalayaCompound;

  IERC20 public cETHV2 = IERC20(0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5);
  address public cWETHV3 = 0xA17581A9E3356d9A858b789D68B4d866e593aE94;
  address public cUSDCV3 = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;
  address public cUSDCV3_Polygon = 0xF25212E676D1F7F89Cd72fFEe66158f541246445;

  address public constant CONNEXT_MAINNET = 0x8898B472C54c31894e3B9bb83cEA802a5d0e63C6;

  uint256 forkIdMainnet;

  uint256 AMOUNT_SUPPLY_WBTC = 1e8;
  uint256 AMOUNT_BORROW_USDC = 10e8;

  function setUp() public {
    forkIdMainnet = vm.createSelectFork("mainnet");
    compoundV2 = new CompoundV2();
    compoundV3 = new CompoundV3();

    himalayaCompound = new HimalayaCompound(CONNEXT_MAINNET);

    vm.label(ALICE, "ALICE");
    vm.label(WETH, "WETH");
    vm.label(WSTETH, "WSTETH");
    vm.label(USDC, "USDC");
    vm.label(WBTC, "WBTC");

    vm.label(address(compoundV2), "compoundV2");
    vm.label(address(compoundV3), "compoundV3");
    vm.label(address(himalayaCompound), "himalayaCompound");

    vm.label(address(cETHV2), "cETHV2");
    vm.label(cWETHV3, "cWETHV3");
    vm.label(cUSDCV3, "cUSDCV3");
  }

  function _utils_depositV2(uint256 amount, address asset) private {
    address cTokenAddr = address(cETHV2);

    _enterCollatMarketV2(cTokenAddr);

    uint256 balanceCTokenBefore = IERC20(cTokenAddr).balanceOf(address(this));
    if (_isWETH(asset)) {
      ICETH cETH = ICETH(cTokenAddr);
      // unwrap WETH to ETH
      IWETH9(asset).withdraw(amount);

      // cEth reverts if mint unsuccessful
      cETH.mint{value: amount}();
    } else {
      ICERC20 cToken = ICERC20(cTokenAddr);

      cToken.mint(amount);
    }

    uint256 balanceCTokenAfter = IERC20(cTokenAddr).balanceOf(address(this));
    IERC20(cTokenAddr).transfer(msg.sender, balanceCTokenAfter - balanceCTokenBefore);
  }

  function _enterCollatMarketV2(address asset) private {
    IComptroller comptroller = IComptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);

    address[] memory markets = new address[](1);
    markets[0] = asset;
    comptroller.enterMarkets(markets);
  }

  function _isWETH(address asset) private pure returns (bool) {
    return asset == 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  }

  function providerNameV2() private pure returns (string memory) {
    return "Compound_V2";
  }

  function _utils_depositV3(
    // address user,
    uint256 amount,
    address asset,
    address cMarketV3
  )
    internal
    returns (bool success)
  {
    ICompoundV3(cMarketV3).supply(asset, amount);
    success = true;
  }

  function test_handleOutboundFromV2ToV3() public {
    deal(WETH, ALICE, 100e18);
    assertEq(IERC20(WETH).balanceOf(ALICE), 100e18);

    //Deposit 100 WETH into CompoundV2
    vm.startPrank(ALICE);
    _utils_depositV2(100e18, WETH);
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
