import { createPublicClient, http, getContract } from "viem";
import { sepolia } from "viem/chains";
import contractABI from "../constants/contractABI.json";


import { CONTRACT_ADDRESS } from "@/constants/addresses";
import { isAddress, ethers } from "ethers";

const BigNumber = ethers.toBigInt(1000)

const publicClient = createPublicClient({
    chain: sepolia,
    transport: http(),
});

const contract = getContract({
    address: CONTRACT_ADDRESS,
    abi: contractABI,
    client: publicClient,
});
export const getTotalLiquidity = async () => {
    try {
        const liquidity = await contract.read.totalLiquidity(); // Call contract function
        return liquidity.toString(); // Convert BigInt to string
    } catch (error) {
        console.error("Error fetching liquidity:", error);
        throw error;
    }
};


export const totalDebt = async (address) => {
    try {
        if (!isAddress(address)) {
            throw new Error("Invalid ethereum address")
        }
        const totalDebt = await contract.read.getDebt(address);
        return totalDebt;
    } catch (error) {
        console.log("Error fetching the total debt", error);
        throw error;
    }
}
export const totalDebtInETH = async (address) => {
    try {
        if (!isAddress(address)) {
            throw new Error("Invalid ethereum address")
        }
        const totalDebtInETH = await contract.read.getDebtInETH(address);
        return totalDebtInETH;
    } catch (error) {
        console.log("Error fetching the total debt", error);
        throw error;
    }
}

export const totalDebtIncludingInterest = async (address) => {
    try {
        if (!isAddress(address)) {
            throw new Error("Invalid ethereum address")
        }
        const totalIncuredDebt = await contract.read.getTotalDebtAmountIncludingInterest(address);
        return totalIncuredDebt;
    } catch (error) {
        console.log("Error fetching the total incured debt", error);
        throw error;
    }
}

export const calculateRequiredCollateral = async (usdtAmount) => {
    try {
        if (!usdtAmount || isNaN(usdtAmount) || BigNumber.from(usdtAmount).lt(0)) {
            throw new Error("Invalid USDT amount. It must be a positive number.");
        }

        const amount = BigNumber.from(usdtAmount);
        const totalCollateralRequired = await contract.read.calculateRequiredCollateral(amount);
        return totalCollateralRequired;
    } catch (error) {
        console.log("Error fetching the total collateral required", error);
        throw error;

    }
}


export const calculateInterestRate = async () => {
    try {
        const interesetRate = await contract.read.calculateInterestRate()
        return interesetRate;
    }
    catch (error) {
        console.log("Error fetching the current interest rate of the model", error);
        throw error;

    }
}

export const getDepositAmount = async (address) => {
    try {
        if (!isAddress(address)) {
            throw new Error("Invalid ethereum address")
        }
        const depositAmount = await contract.read.getDepositAmount();
        return depositAmount
    } catch (error) {
        console.log("Error fetching the deposit amount", error);
        throw error;
    }
}
export const getCollateralAmount = async (address) => {
    try {
        if (!isAddress(address)) {
            throw new Error("Invalid ethereum address")
        }
        const collateralAmount = await contract.read.getCollateralAmount(address);
        return collateralAmount;
    } catch (error) {
        console.log("Error fetching the deposit amount", error);
        throw error;
    }
}
export const getCurrentLPTokenValue = async () => {
    try {
        const lpTokenValue = await contract.read.getCurrentLPTokenValue();
        return lpTokenValue;
    } catch (error) {
        console.log("Error fetching the deposit amount", error);
        throw error;
    }
}

export const getCollaterizartionRatio = async () => {
    try {
        const collaterizarionRatio = await contract.read.COLLATERALIZATION_RATIO();
    } catch (error) {
        console.log("Error fetching the deposit amount", error);
        throw error;
    }
}
export const getLiquidationThreshold = async () => {
    try {
        const liquidationThreshold = await contract.read.LIQUIDATION_THRESHOLD();
        return liquidationThreshold;
    } catch (error) {
        console.log("Error fetching the deposit amount", error);
        throw error;
    }
}