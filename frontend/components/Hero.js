import "../styles/hero.css"; // Import CSS

export default function Hero() {
  return (
    <>
      <section className="hero">
        <div className="hero-container">
          <h1 className="hero-title">Decentralized Money Lending</h1>
          <p className="hero-subtitle">
            Borrow and lend crypto assets securely with smart contracts.
          </p>
          <button className="hero-btn">Get Started</button>
        </div>
      </section>
    </>
  );
}