import "../styles/footer.css";

export default function Footer() {
  return (
    <>
      <footer className="footer">
        <div className="footer-container">
          <p>© {new Date().getFullYear()} MoneyLend. All rights reserved.</p>
          <div className="footer-links">
            <a href="/terms">Terms</a>
            <a href="/privacy">Privacy</a>
          </div>
        </div>
      </footer>
    </>
  );
}