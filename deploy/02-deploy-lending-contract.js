const { network } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts();

  const priceFeed = "0x694AA1769357215DE4FAC081bf1f309aDC325306";
  const usdtTokenAddress = "0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E";
  const lpTokenAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";//localhost
  // const lpTokenAddress = "0x4D3d09E0C6B6a2Ef265eF9e03ebf5398a7BB4398";//sepolia

  const args = [priceFeed, usdtTokenAddress, lpTokenAddress];
  log("Deployments started");

  const lendingContract = await deploy("FinalLendingPoolContract", {
    from: deployer,
    args: args,
    log: true,
    blockConfirmations: network.config.blockConfirmations || 1,
  });

  log(`The lending pool contract deployed to the address ${lendingContract.address}`);

  return {
    tags: ["all", "FinalLendingPoolContract"],
  };
};
