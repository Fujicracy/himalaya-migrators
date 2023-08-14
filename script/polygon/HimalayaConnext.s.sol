// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "../../src/migrators/HimalayaConnext.sol";
import "../../src/interfaces/IHimalayaConnext.sol";

contract DeployHimalayaConnext is Script {
  //Polygon Connext
  address public constant CONNEXT_POLYGON = 0x11984dc4465481512eb5b777E44061C158CF2259;

  function setUp() public {}

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);
    IHimalayaConnext himalayaConnext = new HimalayaConnext(CONNEXT_POLYGON);

    vm.stopBroadcast();
  }
}
