const { ethers } = require("hardhat");
const { ASSETS } = require("../scripts/const");

const setStorageAt = async (address, index, value) => {
  await ethers.provider.send("hardhat_setStorageAt", [address, index, value]);
  await ethers.provider.send("evm_mine", []); // Just mines to the next block
};

const getStorageSlot = (address, chain, method) => {
  const assets = Object.values(ASSETS[chain]);
  const asset = assets.find((e) => e.address == address);
  const slot = asset.storageSlots[method];
  if (!Number.isInteger(slot)) {
    throw "Set storage slot in 'ASSETS' object; Refer to https://github.com/kendricktan/slot20 on how get slot number.";
  }
  return asset.storageSlots[method];
};

/**
 * Sets ERC20 balance for testing purposes
 * @param {string} userAddr
 * @param {string} erc20address
 * @param {string} chain name
 * @param {Object} BNbalance in ethers.BigNumber format
 */
const setERC20UserBalance = async (
  userAddr,
  erc20address,
  chain,
  BNbalance
) => {
  // Get storage slot index
  const slot = getStorageSlot(erc20address, chain, "balanceOf");
  const solidityIndex = ethers.utils.solidityKeccak256(
    ["uint256", "uint256"],
    [userAddr, slot] // key, slot
  );
  // Manipulate local balance (needs to be bytes32 string)
  await setStorageAt(
    erc20address,
    solidityIndex.toString(),
    toBytes32(BNbalance).toString()
  );
};
