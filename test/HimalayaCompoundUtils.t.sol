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

contract HimalayaCompoundUtils is Test {
  uint256 public constant ALICE_PK = 0xA;
  address public ALICE = vm.addr(ALICE_PK);

  //Mainnet ERC20
  address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
  address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

  //Compound Integrations
  CompoundV2 public compoundV2; //only on mainnet
  CompoundV3 public compoundV3;

  //HimalayaCompound
  IHimalayaMigrator public himalayaCompound; //TODO create also for other chains (himalayaCompoundArbitrum and polygon after contracts have been created)

  //Mainnet Compound Markets
  IERC20 public cETHV2 = IERC20(0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5);
  address public cWETHV3 = 0xA17581A9E3356d9A858b789D68B4d866e593aE94;
  address public cUSDCV3 = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;
  //Polygon Compound Markets
  address public cUSDCV3_Polygon = 0xF25212E676D1F7F89Cd72fFEe66158f541246445;

  //Mainnet Connext
  address public constant CONNEXT_MAINNET = 0x8898B472C54c31894e3B9bb83cEA802a5d0e63C6;

  uint256 AMOUNT_SUPPLY_WBTC = 1e8;
  uint256 AMOUNT_BORROW_USDC = 10e8;

  function setLabels() internal {
    //TODO rename this function and set this labels dynamically
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

  function _utils_depositV2_mainnet(uint256 amount, address asset) internal {
    address cTokenAddr = address(cETHV2);

    _enterCollatMarketV2_mainnet(cTokenAddr);

    uint256 balanceCTokenBefore = IERC20(cTokenAddr).balanceOf(address(this));
    if (_isWETH_mainnet(asset)) {
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

  function _enterCollatMarketV2_mainnet(address asset) private {
    IComptroller comptroller = IComptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);

    address[] memory markets = new address[](1);
    markets[0] = asset;
    comptroller.enterMarkets(markets);
  }

  function _isWETH_mainnet(address asset) private pure returns (bool) {
    return asset == 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  }

  function providerNameV2_mainnet() private pure returns (string memory) {
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
}