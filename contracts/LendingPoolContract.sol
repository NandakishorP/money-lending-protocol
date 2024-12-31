// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.7;

// Import statements
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

// Errors
error LendingPoolContract__InvalidAmount();
error LendingPoolContract__InsufficientCollateral();
error LendingPoolContract__LoanLimitExceeded();
error LendingPoolContract__RepaymentFailed();
error LendingPoolContract__SafeRatio();

// Main Contract
contract LendingPoolContract is ReentrancyGuard {
  // Mappings for deposit and collateral
  mapping(address => uint256) public depositAmount; // Tracks deposit balance
  mapping(address => uint256) public collateralAmount; // Tracks collateral balance
  mapping(address => uint256) public loanAmount; // Tracks loan balance
  mapping(address => uint256) public repaymentDeadline; // Tracks repayment deadlines

  uint256 private constant COLLATERALIZATION_RATIO = 60;
  uint256 private constant LIQUIDATION_THRESHOLD = 85;
  uint256 private totalLiquidity;

  // Chainlink price feed
  AggregatorV3Interface internal immutable priceFeed;
  IERC20 public immutable usdtToken;

  // Events
  event Deposit(address indexed user, uint256 amount);
  event Collateral(address indexed user, uint256 amount);
  event Borrow(address indexed user, uint256 usdtAmount);
  event Repay(address indexed user, uint256 repaymentAmount);
  event Liquidate(address indexed borrower, uint256 loanCleared);

  constructor(address _priceFeedAddress, address _usdtTokenAddress) {
    priceFeed = AggregatorV3Interface(_priceFeedAddress);
    usdtToken = IERC20(_usdtTokenAddress);
  }

  // Deposit Funds for Earning Interest (Funds cannot be used as collateral)
  function depositFunds() external payable nonReentrant {
    if (msg.value == 0) revert LendingPoolContract__InvalidAmount();

    depositAmount[msg.sender] += msg.value;
    totalLiquidity += msg.value;

    emit Deposit(msg.sender, msg.value);
  }

  // Provide Collateral for Loans
  function provideCollateral() external payable nonReentrant {
    if (msg.value == 0) revert LendingPoolContract__InvalidAmount();

    collateralAmount[msg.sender] += msg.value;

    emit Collateral(msg.sender, msg.value);
  }

  // Borrow function
  function borrow(uint256 amount) external nonReentrant {
    uint256 collateralValue = collateralAmount[msg.sender];

    // Check if collateral is sufficient
    uint256 requiredCollateral = (amount * COLLATERALIZATION_RATIO) / 100;
    if (collateralValue < requiredCollateral)
      revert LendingPoolContract__InsufficientCollateral();

    loanAmount[msg.sender] += amount;

    // Transfer USDT to borrower (you need to implement the USDT transfer logic)
    usdtToken.transfer(msg.sender, amount);

    emit Borrow(msg.sender, amount);
  }

  // Repay Loan function
  function repayLoan(uint256 amount) external nonReentrant {
    if (loanAmount[msg.sender] < amount)
      revert LendingPoolContract__LoanLimitExceeded();

    loanAmount[msg.sender] -= amount;
    // Implement repayment logic (e.g., transfer USDT back)

    emit Repay(msg.sender, amount);
  }

  // Liquidate function for collateral when safe ratio is exceeded
  function liquidate(address borrower) external nonReentrant {
    uint256 collateralValue = collateralAmount[borrower];
    uint256 loanValue = loanAmount[borrower];
    uint256 ethPrice = getLatestPrice();

    uint256 liquidationThreshold = (loanValue * LIQUIDATION_THRESHOLD) / 100;
    if (collateralValue * ethPrice < liquidationThreshold) {
      // Logic for liquidating collateral, transfer the collateral to the lender or pool
      collateralAmount[borrower] = 0;
      emit Liquidate(borrower, loanValue);
    }
  }

  // Get the latest price of ETH in terms of USDT
  function getLatestPrice() public view returns (uint256) {
    (, int256 price, , , ) = priceFeed.latestRoundData();
    return uint256(price);
  }
}
