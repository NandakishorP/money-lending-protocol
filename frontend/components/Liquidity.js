"use client";

import { useState, useEffect } from "react";
import { getTotalLiquidity } from "@/utils/viemClient"; // Import the viem client

export default function Liquidity() {
    const [liquidity, setLiquidity] = useState("Loading...");

    useEffect(() => {
        const cachedLiquidity = localStorage.getItem("liquidity");
        if (cachedLiquidity) {
            setLiquidity(cachedLiquidity);
        }
        const fetchLiquidity = async () => {
            try {
                const liq = await getTotalLiquidity();
                setLiquidity(liq);
                localStorage.setItem("liquidity", liq);
            } catch (error) {
                console.error("Error fetching liquidity:", error);
                setLiquidity("Error loading data");
            }
        };
        fetchLiquidity();
    }, []);

    return (
        <div>
            <h1>Total Liquidity: {liquidity}</h1>
        </div>
    );
}