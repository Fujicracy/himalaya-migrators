// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {IWETH9} from "@fuji-v2/src/abstracts/WETH9.sol";
import {IHimalayaConnext} from "../src/interfaces/IHimalayaConnext.sol";

contract Utils is Test {
  uint256 public constant ALICE_PK = 0xA;
  address public ALICE = vm.addr(ALICE_PK);

  IHimalayaConnext public himalayaConnext_Polygon =
    IHimalayaConnext(0x65af59cF04176638836E500EA9bD681795c91ae9);
  IHimalayaConnext public himalayaConnext = IHimalayaConnext(address(0));

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
  uint256 AMOUNT_BORROW_USDC = 10e8;

  function setLabels() internal {
    vm.label(ALICE, "ALICE");
    vm.label(WETH, "WETH");
    vm.label(WSTETH, "WSTETH");
    vm.label(USDC, "USDC");
    vm.label(WBTC, "WBTC");
    vm.label(WETH_Arbitrum, "WETH_Arbitrum");
    vm.label(USDC_Arbitrum, "USDC_Arbitrum");
    vm.label(WBTC_Arbitrum, "WBTC_Arbitrum"");
    vm.label(WETH_Polygon, "WETH_Polygon");
    vm.label(USDC_Polygon, "USDC_Polygon");
    vm.label(WBTC_Polygon, "WBTC_Polygon");
  }
}
