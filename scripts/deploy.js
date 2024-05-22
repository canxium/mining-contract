// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const { ethers, upgrades } = require("hardhat");

async function main() {
  const contract = await ethers.getContractFactory("MiningRewardDistribution");
  const mc = await upgrades.deployProxy(contract, { 
    kind: 'uups',
    txOverrides: {
      maxPriorityFeePerGas: 1000000000,
      maxFeePerGas: 400000000000,
    }
  });

  await mc.waitForDeployment();
  console.log("Contract deployed to:", await mc.getAddress());

  // const BoxV2 = await ethers.getContractFactory("MiningRewardDistribution");
  // const upgraded = await upgrades.upgradeProxy("0x9e58d6888D42D3006Edc7Db1C1109F68E2C6Fe52", BoxV2, {
  //   txOverrides: {
  //     maxPriorityFeePerGas: 1000000000,
  //     maxFeePerGas: 400000000000,
  //   }
  // });

  // await upgraded.waitForDeployment();
  // console.log("Contract upgrade deployed to:", upgraded.getAddress());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
