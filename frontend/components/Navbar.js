"use client";

import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useAccount } from "wagmi";
import Link from "next/link";
import "../styles/navbar.css"; // Import the CSS file

export default function Navbar() {
  const { isConnected } = useAccount(); // Check if wallet is connected

  return (
    <nav className="navbar">
      <div className="container">
        {/* 🏠 Brand Logo & Name */}
        <h1 className="brand-title">💰 MoneyLend</h1>

        {/* 🔗 Navigation Links */}
        <div className="nav-links">
          <Link href="/" className="nav-link">Home</Link>
          {isConnected && (
            <>
              <Link href="/liquidity" className="nav-link">Dashboard</Link>
              <Link href="/how-it-works" className="nav-link">Lend</Link>
              <Link href="/how-it-works" className="nav-link">About us</Link>
            </>
          )}
          {!isConnected && (

            <Link href="/how-it-works" className="nav-link">How It Works</Link>
          )}
          <Link href="/docs" className="nav-link">Docs</Link>
        </div>

        {/* 🎛️ Conditional Rendering Based on Connection */}
        <div className="right-section">
          <ConnectButton showBalance={false} />
        </div>
      </div>
    </nav>
  );
}