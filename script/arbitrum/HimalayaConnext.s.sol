// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "../../src/migrators/HimalayaConnext.sol";
import "../../src/interfaces/IHimalayaConnext.sol";

contract DeployHimalayaConnext is Script {
  address public constant CONNEXT_ARBITRUM = 0xEE9deC2712cCE65174B561151701Bf54b99C24C8;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        IHimalayaConnext himalayaConnext = new HimalayaConnext(CONNEXT_ARBITRUM);

        vm.stopBroadcast();
    }
}
