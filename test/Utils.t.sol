// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {IWETH9} from "@fuji-v2/src/abstracts/WETH9.sol";
import {IHimalayaConnext} from "../src/interfaces/IHimalayaConnext.sol";
import {TimelockController} from
  "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import {Chief} from "@fuji-v2/src/Chief.sol";
import {HimalayaCompoundUtils} from "./HimalayaCompoundUtils.t.sol";
import {ConnextUtils} from "./ConnextUtils.t.sol";
import {HimalayaCompound} from "../src/migrators/HimalayaCompound.sol";

contract Utils is Test, HimalayaCompoundUtils, ConnextUtils {
  Chief public chief;
  TimelockController public timelock;

  uint256 public constant ALICE_PK = 0xA;
  address public ALICE = vm.addr(ALICE_PK);

  IHimalayaConnext public himalayaConnext_Polygon =
    IHimalayaConnext(0x65af59cF04176638836E500EA9bD681795c91ae9);
  IHimalayaConnext public himalayaConnext = IHimalayaConnext(address(0));
  IHimalayaConnext public himalayaConnext_Arbitrum =
    IHimalayaConnext(0x65af59cF04176638836E500EA9bD681795c91ae9);

  //Mainnet ERC20
  address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
  address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

  //Polygon ERC20
  address public constant WETH_Polygon = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
  address public constant USDC_Polygon = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
  address public constant WBTC_Polygon = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6;

  //Arbitrum ERC20
  address public constant WETH_Arbitrum = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
  address public constant USDC_Arbitrum = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
  address public constant WBTC_Arbitrum = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;

  uint256 AMOUNT_SUPPLY_WBTC = 1e8;
  uint256 AMOUNT_SUPPLY_WETH = 1e18;
  uint256 AMOUNT_BORROW_USDC = 1000e6;

  function setLabels() internal {
    vm.label(ALICE, "ALICE");
    vm.label(WETH, "WETH");
    vm.label(WSTETH, "WSTETH");
    vm.label(USDC, "USDC");
    vm.label(WBTC, "WBTC");
    vm.label(WETH_Arbitrum, "WETH_Arbitrum");
    vm.label(USDC_Arbitrum, "USDC_Arbitrum");
    vm.label(WBTC_Arbitrum, "WBTC_Arbitrum");
    vm.label(WETH_Polygon, "WETH_Polygon");
    vm.label(USDC_Polygon, "USDC_Polygon");
    vm.label(WBTC_Polygon, "WBTC_Polygon");
  }

  function setTimelock() internal {
    chief = new Chief(true, true);
    timelock = TimelockController(payable(chief.timelock()));
  }

  function addMarkets_mainnet() internal {
    address[] memory marketsV2 = new address[](3);
    marketsV2[0] = address(cETHV2);
    marketsV2[1] = address(cUSDCV2);
    marketsV2[2] = address(cUSDTV2);

    bool[] memory isMarketActiveV2 = new bool[](3);
    isMarketActiveV2[0] = true;
    isMarketActiveV2[1] = true;
    isMarketActiveV2[2] = true;

    address[] memory marketsV3 = new address[](2);
    marketsV3[0] = cWETHV3;
    marketsV3[1] = cUSDCV3;

    bool[] memory isMarketActiveV3 = new bool[](2);
    isMarketActiveV3[0] = true;
    isMarketActiveV3[1] = true;

    vm.prank(address(timelock));
    HimalayaCompound(payable(address(himalayaCompound))).setMarketsV2(marketsV2, isMarketActiveV2);

    vm.prank(address(timelock));
    HimalayaCompound(payable(address(himalayaCompound))).setMarketsV3(marketsV3, isMarketActiveV3);
  }

  function addMarkets_polygon() internal {
    address[] memory marketsV3 = new address[](1);
    marketsV3[0] = cUSDCV3_Polygon;

    bool[] memory isMarketActiveV3 = new bool[](1);
    isMarketActiveV3[0] = true;

    vm.prank(address(timelock));
    HimalayaCompound(payable(address(himalayaCompound))).setMarketsV3(marketsV3, isMarketActiveV3);
  }

  function addMarkets_arbitrum() internal {
    address[] memory marketsV3 = new address[](1);
    marketsV3[0] = cUSDCV3_Arbitrum;

    bool[] memory isMarketActiveV3 = new bool[](1);
    isMarketActiveV3[0] = true;

    vm.prank(address(timelock));
    HimalayaCompound(payable(address(himalayaCompound))).setMarketsV3(marketsV3, isMarketActiveV3);
  }

  function addMarketsDestChain_mainnet() internal {
    uint48[] memory chainIds = new uint48[](2);
    chainIds[0] = 137;
    chainIds[1] = 42161;

    address[] memory markets = new address[](2);
    markets[0] = cUSDCV3_Polygon; //polygon cUSDCV3
    markets[1] = cUSDCV3_Arbitrum; //arbitrum cUSDCV3

    bool[] memory isMarketActive = new bool[](2);
    isMarketActive[0] = true;
    isMarketActive[1] = true;

    vm.prank(address(timelock));
    HimalayaCompound(payable(address(himalayaCompound))).setMarketsDestChain(
      chainIds, markets, isMarketActive
    );
  }

  function addMarketsDestChain_arbitrum() internal {
    uint48[] memory chainIds = new uint48[](3);
    chainIds[0] = 137;
    chainIds[1] = 1;
    chainIds[2] = 1;

    address[] memory markets = new address[](3);
    markets[0] = cUSDCV3_Polygon; //polygon cUSDCV3
    markets[1] = cUSDCV3; //mainnet cUSDCV3
    markets[2] = cWETHV3; //mainnet cWETHV3

    bool[] memory isMarketActive = new bool[](3);
    isMarketActive[0] = true;
    isMarketActive[1] = true;
    isMarketActive[2] = true;

    vm.prank(address(timelock));
    HimalayaCompound(payable(address(himalayaCompound))).setMarketsDestChain(
      chainIds, markets, isMarketActive
    );
  }

  function addMarketsDestChain_polygon() internal {
    uint48[] memory chainIds = new uint48[](3);
    chainIds[0] = 42161;
    chainIds[1] = 1;
    chainIds[2] = 1;

    address[] memory markets = new address[](3);
    markets[0] = cUSDCV3_Arbitrum; //arbitrum cUSDCV3
    markets[1] = cUSDCV3; //mainnet cUSDCV3
    markets[2] = cWETHV3; //mainnet cWETHV3

    bool[] memory isMarketActive = new bool[](3);
    isMarketActive[0] = true;
    isMarketActive[1] = true;
    isMarketActive[2] = true;

    vm.prank(address(timelock));
    HimalayaCompound(payable(address(himalayaCompound))).setMarketsDestChain(
      chainIds, markets, isMarketActive
    );
  }
}
