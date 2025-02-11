const Features = () => {
  return (
    <>
      <section className="py-20 px-6 bg-white">
        <h2 className="text-3xl font-bold text-center">Why Choose Us?</h2>
        <div className="mt-10 grid grid-cols-1 md:grid-cols-3 gap-6 text-center">
          <div className="p-6 shadow-lg rounded-lg">
            <h3 className="text-xl font-semibold">Low Interest Rates</h3>
            <p className="mt-2 text-gray-600">Borrow at competitive rates without intermediaries.</p>
          </div>
          <div className="p-6 shadow-lg rounded-lg">
            <h3 className="text-xl font-semibold">Secure & Transparent</h3>
            <p className="mt-2 text-gray-600">All transactions are recorded on the blockchain.</p>
          </div>
          <div className="p-6 shadow-lg rounded-lg">
            <h3 className="text-xl font-semibold">Instant Liquidity</h3>
            <p className="mt-2 text-gray-600">Lend and withdraw funds at any time.</p>
          </div>
        </div>
      </section>
    </>
  );
};

export default Features;