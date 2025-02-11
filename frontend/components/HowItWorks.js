const HowItWorks = () => {
  return (
    <>
      <section className="py-20 px-6 bg-gray-100">
        <h2 className="text-3xl font-bold text-center">How It Works</h2>
        <div className="mt-10 grid grid-cols-1 md:grid-cols-3 gap-6 text-center">
          <div className="p-6 bg-white shadow-lg rounded-lg">
            <h3 className="text-xl font-semibold">1. Connect Wallet</h3>
            <p className="mt-2 text-gray-600">Use MetaMask or any Web3 wallet to start.</p>
          </div>
          <div className="p-6 bg-white shadow-lg rounded-lg">
            <h3 className="text-xl font-semibold">2. Lend or Borrow</h3>
            <p className="mt-2 text-gray-600">Lend funds or take a loan based on collateral.</p>
          </div>
          <div className="p-6 bg-white shadow-lg rounded-lg">
            <h3 className="text-xl font-semibold">3. Earn or Repay</h3>
            <p className="mt-2 text-gray-600">Lenders earn interest, borrowers repay easily.</p>
          </div>
        </div>
      </section>
    </>
  );
};

export default HowItWorks;