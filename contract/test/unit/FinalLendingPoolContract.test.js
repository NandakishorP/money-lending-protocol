const { ethers, getNamedAccounts, deployments, network } = require("hardhat");
const { expect } = require("chai");
const { BigNumber } = require("ethers");
describe("FinalLendingPoolContract", function () {
    let lendingPoolContract, lpToken, deployer, user1, user2, mockV3Aggregator, usdtToken;
    beforeEach(async () => {
        const DECIMALS = 8;
        const INITIAL_PRICE = ethers.utils.parseUnits("2000", DECIMALS);
        const MockV3Aggregator = await ethers.getContractFactory("MockV3Aggregator");
        mockV3Aggregator = await MockV3Aggregator.deploy(DECIMALS, INITIAL_PRICE);
        await mockV3Aggregator.deployed();
        const MockUSDTToken = await ethers.getContractFactory("MockUSDT");
        usdtToken = await MockUSDTToken.deploy("Tether USD", "USDT", 60);
        await usdtToken.deployed();
        const initialUSDTBalance = ethers.utils.parseUnits("1000000", 6);
        [deployer, user1, user2] = await ethers.getSigners();
        await usdtToken.mint(deployer.address, initialUSDTBalance);
        const LPTokenFactory = await ethers.getContractFactory("LPToken");
        lpToken = await LPTokenFactory.deploy("LP Token", "LPT", {
            gasLimit: 5000000,
            gasPrice: ethers.utils.parseUnits("10", "gwei"),
        });
        await lpToken.deployed();
        const FinalLendingPoolContractFactory = await ethers.getContractFactory("FinalLendingPoolContract");
        lendingPoolContract = await FinalLendingPoolContractFactory.deploy(
            mockV3Aggregator.address,
            usdtToken.address,
            lpToken.address,
            {
                gasLimit: 5000000,
                gasPrice: ethers.utils.parseUnits("10", "gwei"),
            }
        );
        await lendingPoolContract.deployed();
        await usdtToken.transfer(lendingPoolContract.address, initialUSDTBalance);
        await lpToken.connect(deployer).setLendingPool(lendingPoolContract.address);
    });
    it("should deploy FinalLendingPoolContract", async () => {
        expect(lendingPoolContract.address).to.be.properAddress;
    });
    it("should deploy LPToken contract", async () => {
        expect(lpToken.address).to.be.properAddress;
    });
    it("should correctly initialize lpToken address in the constructor", async () => {
        const storedLPToken = await lendingPoolContract.lpToken();
        expect(storedLPToken).to.equal(lpToken.address);
    });
    it("should correctly initialize usdtToken address in the constructor", async () => {
        const storedUsdtToken = await lendingPoolContract.usdtToken();
        expect(storedUsdtToken).to.equal(usdtToken.address);
    });
    it("should correctly initialize priceFeed address in the constructor", async () => {
        const storedPriceFeed = await lendingPoolContract.PRICE_FEED();
        expect(storedPriceFeed).to.equal(mockV3Aggregator.address);
    });
    //TESTING THE DEPOSIT FUNCTION
    // testing the revert condition for depositing zero eth
    it("should revert when the deposit amount is 0 ETH", async () => {
        await expect(lendingPoolContract.connect(deployer).
            depositFunds({ value: 0 }))
            .to.be.revertedWith("FinalLendingPoolContract__NotEnoughAmount")
    })
    //general testing for single user deposit
    it("should allow users to deposit funds and mint LP Tokens", async () => {
        const depositValue = await ethers.utils.parseEther("10");
        const tx = await lendingPoolContract.connect(deployer).depositFunds({ value: depositValue });
        await tx.wait();
        const deployerDeposit = await lendingPoolContract.getDepositAmount(deployer.address);
        expect(deployerDeposit).to.equal(depositValue);
        const totalLiquidity = await lendingPoolContract.totalLiquidity();
        expect(totalLiquidity).to.equal(depositValue);
        const lpTokenBalance = await lpToken.balanceOf(deployer.address);
        expect(lpTokenBalance).to.equal(depositValue.div(BigNumber.from(10).pow(18))); // Convert Wei to Ether
        await expect(tx)
            .to.emit(lendingPoolContract, "Deposited")
            .withArgs(deployer.address, depositValue);
    });
    //testing for multiple users
    it("should handle multiple deposits correctly", async () => {
        const depositValue1 = await ethers.utils.parseEther("10")
        const depositValue2 = await ethers.utils.parseEther("20")
        await lendingPoolContract.connect(deployer).depositFunds({ value: depositValue1 })
        const tx = await lendingPoolContract.connect(deployer).depositFunds({ value: depositValue2 })
        await tx.wait()
        const depositAmount = await lendingPoolContract.getDepositAmount(deployer.address);
        expect(depositAmount).to.equal(depositValue1.add(depositValue2))
    })
    //  TESTING THE WITHDRAW FUNCTION
    //testing whether the withdraw function is handling the exceptions correctly
    //testing by passing  zero as the withdrawal amount
    it("should revert when the withdrawal amount is zero", async () => {
        const withdrawAmount = ethers.utils.parseEther("0")
        const lpBurnAmount = 2
        await expect(lendingPoolContract.connect(deployer)
            .withdrawDeposits(withdrawAmount, lpBurnAmount))
            .to.be.revertedWith("FinalLendingPoolContract__InvalidWithdrawalParameters")
    })
    //testing by passing zero as the lpToken amount
    it("should revert when the lpToken amount is zero", async () => {
        const withdrawAmount = ethers.utils.parseEther("10")
        const lpBurnAmount = 0
        await expect(lendingPoolContract.connect(deployer).
            withdrawDeposits(withdrawAmount, lpBurnAmount))
            .to.be.revertedWith("FinalLendingPoolContract__InvalidWithdrawalParameters")
    })
    //testing by withdrawing more than deposited

    it("should revert when the requested withdrawal amount exceeds the deposited Ether", async () => {
        const depositValue = ethers.utils.parseEther("5");
        await lendingPoolContract.connect(deployer).depositFunds({ value: depositValue });
        const ethWithdrawAmount = ethers.utils.parseEther("10");
        const lpBurnAmount = 1;
        await expect(
            lendingPoolContract.connect(deployer).withdrawDeposits(ethWithdrawAmount, lpBurnAmount)
        ).to.be.revertedWith("FinalLendingPoolContract__InsufficientEtherBalance");
    });
    //testing by burning more lptoken than owned
    it("should revert when the LP token burn amount exceeds the user's LP token balance", async () => {
        const depositValue = ethers.utils.parseEther("5");
        await lendingPoolContract.connect(deployer).depositFunds({ value: depositValue });
        const ethWithdrawAmount = ethers.utils.parseEther("2");
        const lpBurnAmount = 10;
        await expect(
            lendingPoolContract.connect(deployer).withdrawDeposits(ethWithdrawAmount, lpBurnAmount)
        ).to.be.revertedWith("FinalLendingPoolContract__InsufficientLPTokens");
    });
    //it tests the main features of the withdraw function
    it("allows users to withdraw the funds they deposit and burn the LP Tokens", async () => {
        const depositValue = await ethers.utils.parseEther("10");
        await lendingPoolContract.connect(deployer).depositFunds({ value: depositValue });
        const initialLpTokenBalance = await lpToken.balanceOf(deployer.address);
        expect(initialLpTokenBalance).to.equal(depositValue.div(BigNumber.from(10).pow(18)));
        const initialTotalLiquidity = await lendingPoolContract.totalLiquidity();
        expect(initialTotalLiquidity).to.equal(depositValue);
        const ethWithdrawAmount = ethers.utils.parseEther("3");
        const lpBurnAmount = 2;
        const tx = await lendingPoolContract.connect(deployer).withdrawDeposits(ethWithdrawAmount, lpBurnAmount);
        await tx.wait();
        const deployerFinalDeposit = await lendingPoolContract.getDepositAmount(deployer.address);
        expect(deployerFinalDeposit).to.equal(depositValue.sub(ethWithdrawAmount));
        const finalLpTokenBalance = await lpToken.balanceOf(deployer.address);
        expect(finalLpTokenBalance).to.equal(initialLpTokenBalance.sub(lpBurnAmount));
        await expect(tx)
            .to.emit(lendingPoolContract, "DepositWithdrawn")
            .withArgs(deployer.address, ethWithdrawAmount.add(ethers.utils.parseEther(lpBurnAmount.toString())), lpBurnAmount);
    });
    //it checks the ability of the function to make multiple withdrawals at the same time
    it("should handle multiple withdrawal requests correctly and emit the event", async () => {
        const depositValue = ethers.utils.parseEther("10");
        await lendingPoolContract.connect(deployer).depositFunds({ value: depositValue });
        const initialLpTokenBalance = await lpToken.balanceOf(deployer.address);
        const ethWithdrawAmount1 = ethers.utils.parseEther("3");
        const ethWithdrawAmount2 = ethers.utils.parseEther("2");
        const lpBurnAmount1 = 1;
        const lpBurnAmount2 = 3;
        const tx1 = await lendingPoolContract.connect(deployer).withdrawDeposits(ethWithdrawAmount1, lpBurnAmount1);
        const receipt1 = await tx1.wait();
        const totalLiquidityAfterFirstWithdrawal = await lendingPoolContract.totalLiquidity();
        const lpTokenSupply1 = await lpToken.totalSupply();
        const lpValueInEth1 = lpBurnAmount1 * totalLiquidityAfterFirstWithdrawal / lpTokenSupply1;
        expect(receipt1.events).to.exist;
        expect(receipt1)
            .to.emit(lendingPoolContract, "DepositWithdrawn")
            .withArgs(deployer.address, ethWithdrawAmount1.add(ethers.utils.parseEther(lpValueInEth1.toString())), lpBurnAmount1);
        const tx2 = await lendingPoolContract.connect(deployer).withdrawDeposits(ethWithdrawAmount2, lpBurnAmount2);
        const receipt2 = await tx2.wait();
        const totalLiquidityAfterSecondWithdrawal = await lendingPoolContract.totalLiquidity();
        const lpTokenSupply2 = await lpToken.totalSupply();
        const lpValueInEth2 = lpBurnAmount2 * totalLiquidityAfterSecondWithdrawal / lpTokenSupply2;
        expect(receipt2)
            .to.emit(lendingPoolContract, "DepositWithdrawn")
            .withArgs(deployer.address, ethWithdrawAmount2.add(ethers.utils.parseEther(lpValueInEth2.toString())), lpBurnAmount2);
        const deployerFinalDeposit = await lendingPoolContract.getDepositAmount(deployer.address);
        expect(deployerFinalDeposit).to.equal(
            depositValue.sub(ethWithdrawAmount1.add(ethWithdrawAmount2))
        );
        const finalLpTokenBalance = await lpToken.balanceOf(deployer.address);
        expect(finalLpTokenBalance).to.equal(initialLpTokenBalance.sub(lpBurnAmount1 + lpBurnAmount2));
    });
    //it tests the function to make collateral deposit to borrow funds
    //testing by passing zero deposit amount
    it("should revert when the deposit amount is zero", async () => {
        const depositValue = ethers.utils.parseEther("0")
        await expect(
            lendingPoolContract.connect(deployer).depositCollateral({ value: depositValue }))
            .to.be.revertedWith("FinalLendingPoolContract__NotEnoughAmount")
    })

    it("allows users to deposit collateral to take loans", async () => {
        const depositValue = await ethers.utils.parseEther("5");
        const initalTotalCollateral = await lendingPoolContract.totalCollateral();
        const tx = await lendingPoolContract.connect(user1).depositCollateral({ value: depositValue });
        await tx.wait();
        const userCollateralAmount = await lendingPoolContract.getCollateralAmount(user1.address);
        const finalTotalCollateral = await lendingPoolContract.totalCollateral();
        expect(depositValue).to.equal(userCollateralAmount);
        expect(finalTotalCollateral).to.equal(initalTotalCollateral.add(depositValue));
        await expect(tx)
            .to.emit(lendingPoolContract, "CollateralDeposited")
            .withArgs(user1.address, depositValue);
    });
    it("should allow borrowing funds based on collateral and price feed", async () => {
        const depositCollateralAmount = ethers.utils.parseEther("10");
        await lendingPoolContract.connect(user1).depositCollateral({
            value: depositCollateralAmount,
        });
        const collateralAvailable = await lendingPoolContract.getCollateralAmount(user1.address);
        expect(collateralAvailable).to.equal(depositCollateralAmount);
        const newPrice = ethers.utils.parseUnits("2500", 8);
        await mockV3Aggregator.updateAnswer(newPrice);
        const borrowAmount = ethers.utils.parseUnits("10000", 6);
        await usdtToken.connect(user1).approve(lendingPoolContract.address, borrowAmount);
        const tx = await lendingPoolContract.connect(user1).borrowFunds(borrowAmount);
        await tx.wait();
        const userDebt = await lendingPoolContract.getDebt(user1.address);
        expect(userDebt).to.equal(borrowAmount);
        const userDebtInETh = await lendingPoolContract.getDebtInETH(user1.address);
        await expect(tx)
            .to.emit(lendingPoolContract, "LoanBorrowed")
            .withArgs(user1.address, borrowAmount, userDebtInETh);
    });
    it("should allow borrowing within collateral limits", async function () {
        const depositAmount = ethers.utils.parseEther("10");
        await lendingPoolContract.connect(user1).depositCollateral({ value: depositAmount });
        const collateralAvailable = await lendingPoolContract.getCollateralAmount(user1.address);
        expect(collateralAvailable).to.equal(depositAmount);
        const borrowAmount = ethers.utils.parseUnits("10000", 6);
        await expect(lendingPoolContract.connect(user1).borrowFunds(borrowAmount))
            .to.emit(lendingPoolContract, "LoanBorrowed")
            .withArgs(
                user1.address,
                borrowAmount,
                await lendingPoolContract.getUSDTtoETHPrice(
                    await lendingPoolContract.calculateRequiredCollateral(borrowAmount)
                )
            );
        const amountBorrowedInUSDT = await lendingPoolContract.getDebt(user1.address);
        expect(amountBorrowedInUSDT).to.equal(borrowAmount);
        const remainingCollateral = await lendingPoolContract.getCollateralAmount(user1.address);
        const usedCollateral = await lendingPoolContract.getDebtInETH(user1.address);
        expect(remainingCollateral.add(usedCollateral)).to.equal(depositAmount);
    });
});


// testing for the repay and liquidate and other getter functions are pending