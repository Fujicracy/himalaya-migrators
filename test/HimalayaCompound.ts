// import { expect } from "chai";
// import hre from "hardhat";
import { ethers } from "hardhat";
import { Contract, ContractFactory, utils, Signer } from "ethers";
import { expect } from "chai";
import hre from "hardhat";
import { BigNumber } from "@ethersproject/bignumber";

describe("Crosschain Compound Migration from V2 on ethereum to V3 on arbitrum", function () {
  let HimalayaCompound: ContractFactory;
  let CompoundV2: ContractFactory;
  let CompoundV3: ContractFactory;
  let CompoundV2Helper: ContractFactory;

  let himalayaCompound: Contract;
  let compoundV2: Contract;
  let compoundV3: Contract;
  let compoundV2Helper: Contract;

  let amount = BigNumber.from("1000000000000000000");
  let debtAmount = BigNumber.from("100000000000000000");
  let WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  let WSTETH = "0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0";

  let asset = WETH;
  let debtAsset = WSTETH;

  let cETH = "0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5";
  let cTokenAddr = cETH;

  let cWETHV3 = "0xA17581A9E3356d9A858b789D68B4d866e593aE94";

  let fromChain = 1;
  let toChain = 42161;

  const connext = "0x8898B472C54c31894e3B9bb83cEA802a5d0e63C6";

  let signers: Signer[];

  before(async function () {
    HimalayaCompound = await ethers.getContractFactory("HimalayaCompound");
    CompoundV2 = await ethers.getContractFactory("CompoundV2");
    CompoundV3 = await ethers.getContractFactory("CompoundV3");
    CompoundV2Helper = await ethers.getContractFactory("CompoundV2Helper");

    signers = await ethers.getSigners();

    // We're deploying on Ethereum, Arbitrum, and Polygon
    // For now, just focusing on Ethereum.
    himalayaCompound = await HimalayaCompound.deploy(connext);
    compoundV2 = await CompoundV2.deploy();
    compoundV3 = await CompoundV3.deploy();
    compoundV2Helper = await CompoundV2Helper.deploy();
  });

  it("should make a crosschain transaction", async function () {
    // Give WETH to user
    // let WETHContract = await ethers.getContractAt("WETH", WETH);
    await signers[0].sendTransaction({
      to: WETH,
      value: ethers.utils.parseEther("1"), // Sending 1 ETH
    });
    // expect(
    //   ethers.utils.formatEther(WETHContract.balanceOf(signers[0]))
    // ).to.equal("1");

    // User deposits to CompoundV2
    const depositTx = await compoundV2Helper
      .connect(signers[0])
      .depositV2(amount, asset, cTokenAddr);
    await depositTx.wait();

    // Define Migration Struct
    const migration = {
      owner: await signers[0].getAddress(),
      fromMarket: cTokenAddr,
      toMarket: cWETHV3,
      asset: asset,
      uint256: amount,
      debtAsset: debtAsset,
      debtAmount: debtAmount,
      fromChain: fromChain,
      toChain: toChain,
    };

    // Begin Migration to CompoundV3 via HimalayaCompound
    const migrationTx = await himalayaCompound
      .connect(signers[0])
      .beginXMigration(migration);
    await migrationTx.wait();

    // Get new provider for the Arbitrum network
    const arbitrumProvider = new ethers.providers.JsonRpcProvider(
      "http://localhost:8546"
    );

    // Get account signer for the Arbitrum network
    const arbitrumSigner = arbitrumProvider.getSigner(
      await signers[0].getAddress()
    );

    // Get CompoundV3 instance connected to Arbitrum
    const arbitrumCompoundV3 = compoundV3.connect(arbitrumSigner);

    // Verify the balance on CompoundV3 in Arbitrum
    const balance = await arbitrumCompoundV3.getDepositBalanceV3(
      await signers[0].getAddress()
    );

    // Check the balance
    expect(balance).to.equal(utils.parseEther("10"));
  });
});
