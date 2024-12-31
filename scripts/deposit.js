const { ethers } = require("hardhat");

async function deposit() {
    const lendingContract = await ethers.getContract("LendingPoolContract")
    const lpToken = await ethers.getContract("OurToken")


}

deposit().then(() => process.exit(0)).catch((error => {
    console.log(error);
    process.exit(1)
}))