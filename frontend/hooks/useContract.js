
"use client"
import { useContract, useAccount } from "wagmi";
import { ethers } from "ethers";
import contractABI from "../constants/contractABI.json"; // Import your contract ABI
import { useEffect, useState } from "react";
import { CONTRACT_ADDRESS } from "@/constants/addresses";
import { withdraw } from "viem/zksync";
const RPC_URL = process.env.REACT_APP_ALCHEMY_RPC_URL

export default function useContract() {
    const { isConnected } = useAccount();
    const [contract, setContract] = useState(null);
    const [signer, setSigner] = useState(null);
    useEffect(() => {
        const loadContract = async () => {
            try {
                const provider = isConnected ? new ethers.BrowserProvider(window.ethereum) : new ethers.JsonRpcApiProvider(RPC_URL)
                const signer = isConnected ? await provider.getSigner() : null
                const contractInstance = new ethers.Contract(CONTRACT_ADDRESS, contractABI, signer || provider);

                setContract(contractInstance);
                setSigner(signer);

            } catch (error) {
                console.error("Error initalising contract :", error);

            }
        }
        loadContract()
    }, [isConnected])
    return { contract, signer, isConnected }
}

export const depositFunds = async (contract, signer, depositAmount) => {
    try {
        if (!contract || !signer) {
            throw new Error("Wallet not connected or contract not initalized")
        }
        if (
            !depositAmount ||
            isNaN(depositAmount) ||
            Number(depositAmount) <= 0
        ) {
            throw new Error("Invalid deposit amount. Must be a positive number.");
        }
        try {
            await contract.callStatic.depositFunds({ value: ethers.parseEther(depositAmount.toString()) });
        } catch (error) {
            throw new Error("Transaction would fail: Not enough funds or other issue.");
        }
        const tx = await contract.depositFunds({ value: ethers.parseEther(depositAmount.toString()) })
        await tx.wait()


        console.log("Deposit Succesfull", tx.hash);
        return tx;
    } catch (error) {
        console.error("Fund depositing failed", error);
        throw error;

    }
}

export const depositCollateral = async (contract, signer, depositAmount) => {
    try {
        if (!contract || !signer) {
            throw new Error("Wallet not connected or contract not initalized")
        }
        if (
            !depositAmount ||
            isNaN(depositAmount) ||
            Number(depositAmount) <= 0
        ) {
            throw new Error("Invalid deposit amount. Must be a positive number.");
        }
        try {
            await contract.callStatic.depositCollateral({ value: ethers.parseEther(depositAmount.toString()) });
        } catch (error) {
            throw new Error("Transaction would fail: Not enough funds or other issue.");
        }
        const tx = await contract.depositCollateral({ value: ethers.parseEther(depositAmount.toString()) });
        await tx.wait()

        console.log("Collateral deposit succesfull", tx.hash);
        return tx;
    } catch (error) {
        console.error("Collateral depoist failed");
        throw error;
    }
}

export const withdrawDeposits = async (contract, signer, withdrawAmount, lpTokenAmount) => {
    try {
        if (!contract || !signer) {
            throw new Error("Wallet not connected or contract not initalized")

        }
        if (
            !withdrawAmount ||
            isNaN(withdrawAmount) ||
            Number(withdrawAmount) <= 0 ||
            !lpTokenAmount ||
            isNaN(lpTokenAmount) ||
            Number(lpTokenAmount) <= 0
        ) {
            throw new Error("Invalid withdraw amount. Must be a positive number.");
        }
        const [userDeposit, userLPTokens] = await Promise.all([
            contract.depositAmount(signer.address),
            contract.lpTokenQuantity(signer.address),
        ]);
        if (Number(withdrawAmount) > Number(userDeposit)) {
            throw new Error("Insufficient Ether balance.");
        }
        if (Number(lpTokenAmount) > Number(userLPTokens)) {
            throw new Error("Insufficient LP tokens.");
        }
        try {
            await contract.callStatic.withdrawDeposits(withdrawAmount, lpTokenAmount);
        } catch (error) {
            throw new Error("Transaction would fail: Not enough liquidity or other issue.");
        }
        const tx = await contract.withdrawDeposits(withdrawAmount, lpTokenAmount);
        await tx.wait()
        console.log("Withdrawal Succesfull", tx.hash);
        return tx;

    } catch (error) {
        console.error("Withdrawal failed", error);
        throw error;
    }
}

export const borrowFunds = async (contract, signer, loanAmountNeededInUSDT) => {
    try {
        if (!contract || !signer) {
            throw new Error("Wallet not connected or contract not initalized")
        }
        if (!loanAmountNeededInUSDT || isNaN(loanAmountNeededInUSDT) || Number(loanAmountNeededInUSDT) <= 0) {
            throw new Error("Invalid loan amount. Must be a positive integer")
        }
        const [availableCollateral, collateralRatio, ethToUsdtPrice] = await Promise.all([
            contract.availableCollateralAmount(signer.address),
            contract.COLLATERALIZATION_RATIO(),
            contract.getLatestETHtoUSDTPrice(1)
        ]);
        const possibleLoanAmountInUSDT = ((availableCollateral * collateralRatio) / 100n) * ethToUsdtPrice;
        if (possibleLoanAmountInUSDT < loanAmountNeededInUSDT) {
            throw new Error("Not enough collateral to borrow this amount.");
        }
        try {
            await contract.callStatic.borrowFunds(loanAmountNeededInUSDT);
        } catch (error) {
            throw new Error("Transaction would fail: Not enough collateral or other issue.");
        }
        const tx = await contract.borrowFunds(loanAmountNeededInUSDT);
        await tx.wait()
        console.log("Borrowing succesfull loan amout credited to the wallet", tx.hash);
        return tx;
    } catch (error) {
        console.error("Borrwowing failed", error);
        throw error;
    }
}

export const withdrawCollateral = async (contract, signer, withdrawalAmount) => {
    try {
        if (!contract || !signer) {
            throw new Error("Wallet not connected or contract not initalized")
        }
        if (!withdrawalAmount || isNaN(withdrawalAmount) || Number(withdrawalAmount) <= 0) {
            throw new Error("Invalid withdrawalAmount. Must be a positive number")
        }
        const [availableCollateral] = await Promise.all([contract.availableCollateralAmount(signer.address)])
        if (Number(availableCollateral) < withdrawalAmount) {
            throw new Error("Invalid withdrawal limit,not enough funds in the collateral deposit")
        }
        try {
            await contract.callStatic.withdrawCollateral(withdrawalAmount);
        } catch (error) {
            throw new Error("Transaction would fail,limit exceeded or other issues")
        }
        const tx = await contract.withdrawCollateral(withdrawalAmount);
        await tx.wait();

        console.log("Withdraw of collateral succesfull", tx.hash)
        return tx

    }
    catch (error) {
        console.error("Withdrawal failed", error)
        throw error;
    }
}

// deposit funds function done

// deposit collateral function done

//borrow funds function done

// repay loan function pending

// liquidate function pending

// withdraw collateral funcion done

// withdraw deposit function done
