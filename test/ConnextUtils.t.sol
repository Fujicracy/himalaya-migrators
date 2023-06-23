// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract ConnextUtils is Test {
  //Mainnet Connext
  address public constant CONNEXT_MAINNET = 0x8898B472C54c31894e3B9bb83cEA802a5d0e63C6;
  //Polygon Connext
  address public constant CONNEXT_POLYGON = 0x11984dc4465481512eb5b777E44061C158CF2259;
  //Arbitrum Connext
  address public constant CONNEXT_ARBITRUM = 0xEE9deC2712cCE65174B561151701Bf54b99C24C8;

  uint32 public constant MAINNET_DOMAIN = 6648936;
  uint32 public constant OPTIMISM_DOMAIN = 1869640809;
  uint32 public constant ARBITRUM_DOMAIN = 1634886255;
  uint32 public constant POLYGON_DOMAIN = 1886350457;
  uint32 public constant GNOSIS_DOMAIN = 6778479;
  uint32 public constant GOERLI_DOMAIN = 1735353714;
  uint32 public constant OPTIMISM_GOERLI_DOMAIN = 1735356532;
  uint32 public constant MUMBAI_DOMAIN = 9991;
  //https://github.com/connext/chaindata/blob/main/crossChain.json
}
