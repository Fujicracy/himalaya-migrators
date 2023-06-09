// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {CompoundV2} from "../src/integrations/CompoundV2.sol";
import {CompoundV3} from "../src/integrations/CompoundV3.sol";
import {ICETH} from "@fuji-v2/src/interfaces/compoundV2/ICETH.sol";
import {ICERC20} from "@fuji-v2/src/interfaces/compoundV2/ICERC20.sol";
import {IComptroller} from "@fuji-v2/src/interfaces/compoundV2/IComptroller.sol";
import {IWETH9} from "@fuji-v2/src/abstracts/WETH9.sol";
import {LibCompoundV2} from "@fuji-v2/src/libraries/LibCompoundV2.sol";
import {ICToken} from "@fuji-v2/src/interfaces/compoundV2/ICToken.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IHimalayaMigrator} from "../src/interfaces/IHimalayaMigrator.sol";
import {HimalayaCompound} from "../src/migrators/HimalayaCompound.sol";
import {ICompoundV3} from "@fuji-v2/src/interfaces/compoundV3/ICompoundV3.sol";

/**
 * @dev This contract tests the integration of CompoundV2 and CompoundV3.
 */
contract HimalayaCompoundUnitTests is Test {
  uint256 public constant ALICE_PK = 0xA;
  address public ALICE = vm.addr(ALICE_PK);

  address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
  address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

  CompoundV2 public compoundV2;
  CompoundV3 public compoundV3;

  IHimalayaMigrator public himalayaCompound;

  IERC20 public cTokenV2 = IERC20(0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5);
  address public cWETHV3 = 0xA17581A9E3356d9A858b789D68B4d866e593aE94;

  address public constant CONNEXT_MAINNET = 0x8898B472C54c31894e3B9bb83cEA802a5d0e63C6;

  function setUp() public {
    vm.createSelectFork("mainnet");
    compoundV2 = new CompoundV2();
    compoundV3 = new CompoundV3();

    himalayaCompound = new HimalayaCompound(CONNEXT_MAINNET);

    vm.label(ALICE, "ALICE");
    vm.label(WETH, "WETH");
    vm.label(WSTETH, "WSTETH");
    vm.label(USDC, "USDC");

    vm.label(address(compoundV2), "compoundV2");
    vm.label(address(compoundV3), "compoundV3");
    vm.label(address(himalayaCompound), "himalayaCompound");

    vm.label(address(cTokenV2), "cTokenV2");
    vm.label(cWETHV3, "cWETHV3");
  }

  function _utils_depositV2(uint256 amount, address asset) private {
    address cTokenAddr = address(cTokenV2);

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

  function test_migrateFromV2toV3() public {
    deal(WETH, ALICE, 100e18);
    assertEq(IERC20(WETH).balanceOf(ALICE), 100e18);

    //Deposit 100 WETH into CompoundV2
    vm.startPrank(ALICE);
    _utils_depositV2(100e18, WETH);
    assertApproxEqAbs(compoundV2.getDepositBalanceV2(ALICE, address(cTokenV2)), 100e18, 100e18 / 10);
    assertEq(IERC20(WETH).balanceOf(address(compoundV2)), 0);

    //Migrate 100 WETH deposit position from CompoundV2 to CompoundV3
    uint256 balanceCTokenV2 = cTokenV2.balanceOf(ALICE);

    IHimalayaMigrator.Migration memory migration;
    migration.owner = ALICE;
    migration.fromMarket = address(cTokenV2);
    migration.toMarket = cWETHV3;
    migration.asset = WETH;
    migration.amount = 100e18;
    migration.debtAsset = address(0);
    migration.debtAmount = 0;
    migration.fromChain = 1;
    migration.toChain = 1;

    //approve himalayaCompound to pull cTokens
    cTokenV2.approve(address(himalayaCompound), balanceCTokenV2);

    //TODO add borrow to migration
    himalayaCompound.beginXMigration(migration);
    assertEq(IERC20(WETH).balanceOf(address(himalayaCompound)), 100e18);
    assertEq(compoundV2.getDepositBalanceV2(ALICE, address(cTokenV2)), 0);

    //TODO improve this workflow
    //aprove himalayacompound on destination chain as operator on compoundV3
    ICompoundV3(migration.toMarket).allow(address(himalayaCompound), true);

    //mock bridge behaviour by calling receiveXMigration on destChain (same chain in this case)
    //TODO this call should be verified inside himalayaCompound: either autorized entity or verified parameters
    //No need to send funds since we are on the same chain
    //TODO send parameters in function call instead of empty bytes
    himalayaCompound.receiveXMigration(bytes(""));

    assertApproxEqAbs(
      compoundV3.getDepositBalanceV3(ALICE, WETH, migration.toMarket), 100e18 - 5e18, 2
    );
  }
}
