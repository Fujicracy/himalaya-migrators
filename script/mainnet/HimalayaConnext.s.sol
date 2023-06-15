// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "../../src/migrators/HimalayaConnext.sol";
import "../../src/interfaces/IHimalayaConnext.sol";

contract DeployHimalayaConnext is Script {
  address public constant CONNEXT_MAINNET = 0x8898B472C54c31894e3B9bb83cEA802a5d0e63C6;

  function setUp() public {}

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    IHimalayaConnext himalayaConnext = new HimalayaConnext(CONNEXT_MAINNET);

    vm.stopBroadcast();
  }
}
