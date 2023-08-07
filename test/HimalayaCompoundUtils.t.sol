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
  //Compound Integrations
  CompoundV2 public compoundV2; //only on mainnet
  CompoundV3 public compoundV3;

  //HimalayaCompound
  IHimalayaMigrator public himalayaCompound;

  //Mainnet Compound Markets
  IERC20 public cETHV2 = IERC20(0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5); //cETH
  IERC20 public cDAIV2 = IERC20(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643); //cDAI
  IERC20 public cUSDCV2 = IERC20(0x39AA39c021dfbaE8faC545936693aC917d5E7563); //cUSDC
  IERC20 public cUSDTV2 = IERC20(0xf650C3d88D12dB855b8bf7D11Be6C55A4e07dCC9); //cUSDT
  address public cWETHV3 = 0xA17581A9E3356d9A858b789D68B4d866e593aE94;
  address public cUSDCV3 = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;

  //Polygon Compound Markets
  address public cUSDCV3_Polygon = 0xF25212E676D1F7F89Cd72fFEe66158f541246445;

  //Arbitrum Compound Markets
  address public cUSDCV3_Arbitrum = 0xA5EDBDD9646f8dFF606d7448e414884C7d905dCA;

  // IERC20 public cAAVEV2 = 0xe65cdB6479BaC1e22340E4E755fAE7E509EcD06c; //cAAVE
  // IERC20 public cBATV2 = 0x6C8c6b02E7b2BE14d4fA6022Dfd6d75921D90E4E; //cBAT
  // IERC20 public cCOMPV2 = 0x70e36f6BF80a52b3B46b3aF8e106CC0ed743E8e4; //cCOMP
  // IERC20 public cFEIV2 = 0x7713DD9Ca933848F6819F38B8352D9A15EA73F67; //cFEI
  // IERC20 public cLINKV2 = 0xFAce851a4921ce59e912d19329929CE6da6EB0c7; //cLINK
  // IERC20 public cMKRV2 = 0x95b4eF2869eBD94BEb4eEE400a99824BF5DC325b; //cMKR
  // IERC20 public cREPV2 = 0x158079Ee67Fce2f58472A96584A73C7Ab9AC95c1; //cREP
  // IERC20 public cSAIV2 = 0xF5DCe57282A584D2746FaF1593d3121Fcac444dC; //cSAI
  // IERC20 public cSUSHIV2 = 0x4B0181102A0112A2ef11AbEE5563bb4a3176c9d7; //cSUSHI
  // IERC20 public cTUSDV2 = 0x12392F67bdf24faE0AF363c24aC620a2f67DAd86; //cTUSD
  // IERC20 public cUNIV2 = 0x35A18000230DA775CAc24873d00Ff85BccdeD550; //cUNI
  // IERC20 public cUSDPV2 = 0x041171993284df560249B57358F931D9eB7b925D; //cUSDP
  // IERC20 public cWBTCV2 = 0xC11b1268C1A384e55C48c2391d8d480264A3A7F4; //cWBTC
  // IERC20 public cWBTC2V2 = 0xccF4429DB6322D5C611ee964527D42E5d685DD6a; //cWBTC2
  // IERC20 public cYFIV2 = 0x80a2AE356fc9ef4305676f7a3E2Ed04e12C33946; //cYFI
  // IERC20 public cZRXV2 = 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643; //cZRX

  function setLabelsCompound() internal {
    vm.label(address(compoundV2), "compoundV2");
    vm.label(address(compoundV3), "compoundV3");
    vm.label(address(himalayaCompound), "himalayaCompound");

    vm.label(address(cETHV2), "cETHV2");
    vm.label(cWETHV3, "cWETHV3");
    vm.label(cUSDCV3, "cUSDCV3");

    vm.label(cUSDCV3_Polygon, "cUSDCV3_Polygon");
    vm.label(cUSDCV3_Arbitrum, "cUSDCV3_Arbitrum");
  }

  function addMarkets_mainnet() internal {
    HimalayaCompound hc = HimalayaCompound(payable(address(himalayaCompound)));

    address[] memory marketsV2 = new address[](3);
    marketsV2[0] = address(cETHV2);
    marketsV2[1] = address(cUSDCV2);
    marketsV2[2] = address(cUSDTV2);

    address[] memory marketsV3 = new address[](2);
    marketsV3[0] = cWETHV3;
    marketsV3[1] = cUSDCV3;

    hc.addMarketsV2(marketsV2);
    hc.addMarketsV3(marketsV3);
  }

  function addMarkets_polygon() internal {
    HimalayaCompound hc = HimalayaCompound(payable(address(himalayaCompound)));

    address[] memory marketsV3 = new address[](1);
    marketsV3[0] = cUSDCV3_Polygon;

    hc.addMarketsV3(marketsV3);
  }

  function addMarkets_arbitrum() internal {
    HimalayaCompound hc = HimalayaCompound(payable(address(himalayaCompound)));

    address[] memory marketsV3 = new address[](1);
    marketsV3[0] = cUSDCV3_Arbitrum;

    hc.addMarketsV3(marketsV3);
  }

  function addMarketsDestChain_mainnet() internal {
    HimalayaCompound hc = HimalayaCompound(payable(address(himalayaCompound)));

    uint48[] memory chainIds = new uint48[](2);
    chainIds[0] = 137;
    chainIds[1] = 42161;

    address[] memory markets = new address[](2);
    markets[0] = cUSDCV3_Polygon; //polygon cUSDCV3
    markets[1] = cUSDCV3_Arbitrum; //arbitrum cUSDCV3

    hc.addMarketsDestChain(chainIds, markets);
  }

  function addMarketsDestChain_arbitrum() internal {
    HimalayaCompound hc = HimalayaCompound(payable(address(himalayaCompound)));

    uint48[] memory chainIds = new uint48[](3);
    chainIds[0] = 137;
    chainIds[1] = 1;
    chainIds[2] = 1;

    address[] memory markets = new address[](3);
    markets[0] = cUSDCV3_Polygon; //polygon cUSDCV3
    markets[1] = cUSDCV3; //mainnet cUSDCV3
    markets[2] = cWETHV3; //mainnet cWETHV3

    hc.addMarketsDestChain(chainIds, markets);
  }

  function addMarketsDestChain_polygon() internal {
    HimalayaCompound hc = HimalayaCompound(payable(address(himalayaCompound)));

    uint48[] memory chainIds = new uint48[](3);
    chainIds[0] = 42161;
    chainIds[1] = 1;
    chainIds[2] = 1;

    address[] memory markets = new address[](3);
    markets[0] = cUSDCV3_Arbitrum; //arbitrum cUSDCV3
    markets[1] = cUSDCV3; //mainnet cUSDCV3
    markets[2] = cWETHV3; //mainnet cWETHV3

    hc.addMarketsDestChain(chainIds, markets);
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

  function _utils_borrowV2_mainnet(uint256 amount, address market) internal {
    ICToken cToken = ICToken(address(market));

    uint256 status = cToken.borrow(amount);
    require(status == 0, "borrow failed");
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
