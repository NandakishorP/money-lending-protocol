// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../contracts/LPToken.sol";

// errors
/**
 * @notice Error thrown when the deposit amount is insufficient.
 */

error FinalLendingPoolContract__NotEnoughAmount();
/**
 * @notice Error thrown when there is not enough collateral for the loan.
 */
error FinalLendingPoolContract__NotEnoughCollateral();
/**
 * @notice Error thrown when the loan amount provided is invalid.
 */
error FinalLendingPoolContract__InvalidLoanAmount();
/**
 * @notice Error thrown when the loan repay amount exceeds the pending amount
 */
error FinalLendingPoolContract__LoanRepayLimitExceeded();
/**
 * @notice Error thrown when the user doesn't have any active loans
 */
error FinalLendingPoolContract__NoActiveLoan();
/**
 * @notice Error thrown when the collateral value doesnot fall below the liquidation threshold
 */
error FinalLendingPoolContract__CannotLiquidate();
/**
 * @notice Error thrown when the provided LP Tokens are insufficent to withdraw funds
 */
error FinalLendingPoolContract__NotEnoughLPTokensprovided();
/**
 * @notice Error thrown when the provided LP Tokens exceed the withdrawl limit
 */
error FinalLendingPoolContract__WithdrawalLimitExceeded();
/**
 * @notice Error thrown when the withdrawal transaction fails due to wrong param values.
 */
error FinalLendingPoolContract__WithdrawalTransactionFailed();
/**
 * @notice Error thrown when the withdrawal transaction fails due to invalid function parameters.
 */
error FinalLendingPoolContract__InvalidWithdrawalParameters();
/**
 * @notice Error thrown when the withdrawal transaction fails due to insufficient LP tokens.
 */
error FinalLendingPoolContract__InsufficientLPTokens();
/**
 * @notice Error thrown when the withdrawal transaction fails due to insufficient deposit amount.
 */
error FinalLendingPoolContract__InsufficientEtherBalance();

contract FinalLendingPoolContract is ReentrancyGuard {
  /**
   * @notice Minimum collateral-to-loan ratio to avoid liquidation.
   * @custom:value 60
   * @custom:units Percentage
   */
  uint256 public constant COLLATERALIZATION_RATIO = 60;
  /**
   * @notice The liquidation threshold for the lending pool, expressed as a percentage.
   * @dev A value of `75` represents a 75% threshold for liquidation.
   * @custom:value 75
   * @custom:units Percentage
   */
  uint256 public constant LIQUIDATION_THRESHOLD = 75;

  /**
   * @notice The USDT token contract interface.
   * @dev Allows interaction with the USDT token for transferring between users.
   */
  IERC20 public usdtToken;

  // Structure
  /**
   * @title LoanDetails
   * @notice Represents the details of a loan in the lending pool, including the borrowed amount and collateral.
   */
  struct LoanDetails {
    /**
     * @notice The amount of USDT borrowed in the loan.
     * @dev Denominated in USDT, this is the total borrowed amount.
     */
    uint256 amountBorrowedInUSDT;
    /**
     * @notice The amount of collateral provided for the loan.
     * @dev Denominated in the asset's smallest unit, it secures the loan.
     */
    uint256 collateralUsed;
    /**
     * @notice Timestamp of the last update made to the loan.
     * @dev Tracks time-sensitive changes such as loan repayments or collateral updates.
     */
    uint256 lastUpdate;
  }
  // Mappings

  /**
   * @notice Tracks the total deposit amount for each user.
   * @dev Maps a user's address to the total amount they have deposited into the pool, denominated in Ether.
   */
  mapping(address => uint256) private depositAmount;

  /**
   * @notice Tracks the available collateral amount provided by the user.
   * @dev Maps a user's address to the total amount of collateral they currently have for borrowing, denominated in Ether.
   */
  mapping(address => uint256) private availableCollateralAmount;

  /**
   * @notice Tracks the amount of collateral currently used by each borrower.
   * @dev This mapping keeps track of the portion of a user's collateral that is locked for loan purposes.
   *      The remaining collateral is reflected in the user's available collateral balance.
   */
  mapping(address => uint256) private usedCollateralAmount;

  /**
   * @notice Tracks the loan details for each user.
   * @dev Maps a user's address to the `LoanDetails` struct, which contains:
   *      - The amount borrowed
   *      - The collateral used
   *      Both values are denominated in Ether.
   */
  mapping(address => LoanDetails) private loanCredentials;

  /**
   * @notice Tracks the LPToken balance of each user.
   * @dev This mapping keeps track of the LPToken that each user has earned by depositing funds into the protocol.
   */
  mapping(address => uint256) public lpTokenQuantity;

  //   state variables
  /**
   * @notice The total amount of liquidity available in the lending pool.
   * @dev Represents the sum of all deposits made by users into the pool, denominated in Ether.
   */
  uint256 public totalLiquidity;

  /**
   * @notice The total amount of collateral provided by all users.
   * @dev Represents the cumulative value of all collateral locked in the pool, denominated in Ether.
   */
  uint256 public totalCollateral;
  /**
   * @notice The total amount of lona take by all  users
   * @dev Represents the sum of all the loans taken by the user from the pool,denominated in Ether
   */
  uint256 public totalBorrowed;
  /**
   * @notice Represents the base interest rate for loans.
   * @dev This rate is the foundational interest rate applied to all loans. It is subject to adjustments based on factors like collateral value, loan duration, etc.
   */
  uint256 public baseInterestRate;

  /**
   * @notice Represents the maximum interest rate that can be applied to loans.
   * @dev This rate sets an upper limit on the interest rate that can be applied to loans. It prevents interest rates from exceeding this threshold, regardless of other factors.
   */
  uint256 public maxInterestRate;

  /**
   * @notice LP token contract instance used for minting and burning tokens
   * @dev This variable stores the address of the LPToken contract and provides access to its methods
   */
  LPToken public lpToken;
  //   Immutable variables
  /**
   * @notice The price feed interface used to fetch asset prices.
   * @dev An instance of the `AggregatorV3Interface` from Chainlink, used to retrieve real-time price data
   *      for a specific asset(usdt here). This variable is immutable and set during contract deployment.
   */
  AggregatorV3Interface public immutable PRICE_FEED;
  /**
   * @notice Initializes the contract with the required external dependencies.
   * @dev Sets up the price feed and USDT token contracts by storing their addresses.
   * @param _priceFeedAddress The address of the Chainlink price feed contract for fetching asset prices.
   * @param _usdtAddress The address of the USDT token contract used for lending and borrowing operations.
   */
  constructor(
    address _priceFeedAddress,
    address _usdtAddress,
    address _lpTokenAddress
  ) {
    PRICE_FEED = AggregatorV3Interface(_priceFeedAddress);
    usdtToken = IERC20(_usdtAddress);
    lpToken = LPToken(_lpTokenAddress);
  }

  //   events
  /**
   * @notice Emitted when a user deposits funds into the lending pool.
   * @dev This event logs the deposit details, including the depositor's address and the deposit amount (price).
   * @param depositer The address of the user who made the deposit.
   * @param price The amount of funds deposited, denominated in Ether.
   */
  event Deposited(address indexed depositer, uint256 price);
  /**
   * @notice Emitted when a user deposites collateral into the lending pool
   * @dev This event logs the collateral details,including the depositor's address and the collateral
   * @param depositer The address of the user who deposited the collateral.
   * @param price The amount of funds deposited for collateralization,denominated in Ether
   */
  event CollateralDeposited(address indexed depositer, uint256 price);
  /**
   * @notice Emitted when a user borrows funds from the protocol.
   * @dev Logs the loan details, including the borrower's address and the amounts borrowed in USDT and Ether.
   * @param borrower The address of the user who borrowed funds.
   * @param usdtAmount The amount borrowed in USDT.
   * @param ethAmount The amount borrowed in Ether.
   */
  event LoanBorrowed(
    address indexed borrower,
    uint256 usdtAmount,
    uint256 ethAmount
  );
  /**
   * @notice Emitted when a user repays loan back to the protocol
   * @dev Logs the details,including the repayer's address,amount repayed in USDT and pendingAmount in USDT
   * @param repayer The address of the user who repayed funds
   * @param amountRepayed The amount repayed in USDT
   * @param pendingAmount The pending amount to repay in USDT
   */

  event RepayLoan(
    address indexed repayer,
    uint256 amountRepayed,
    uint256 pendingAmount
  );
  /**
   * @notice Emitted when a user fails to keep the collateral value above the threshold
   * @dev Logs the details,including the borrowers address,amount user took as loan in USDT and collateral in USDT.
   * The balance amount is kept in as a penalty
   * @param borrower The address of the user who repayed funds
   * @param priceInUSDT The amount repayed in USDT
   * @param collateralLiquidatedInUSDT The pending amount to repay in USDT
   */
  event Liquidated(
    address indexed borrower,
    uint256 priceInUSDT,
    uint256 collateralLiquidatedInUSDT
  );
  /**
   * @notice Emitted when a user withdraws deposited funds from the contract
   * @dev Logs the details,including the withdrawers' address,amount user withdrawed in Ether and the number of LP Tokens burend in the process
   * @param withdrawer The address of the user who withdrawed his funds
   * @param withdrawAmount The amount withdrawn in Ether
   * @param lpAmount The number of LP Tokens burned
   */
  event DepositWithdrawn(
    address indexed withdrawer,
    uint256 withdrawAmount,
    uint256 lpAmount
  );
  /**
   * @notice Emitted when a user withdraws collateral from the contract.
   * @dev Logs the user's address, the amount withdrawn, and the remaining collateral balance.
   * @param withdrawer The address of the user who withdrew the funds.
   * @param withdrawAmount The amount of collateral withdrawn, denominated in Ether.
   * @param balanceCollateral The remaining collateral balance after the withdrawal, denominated in Ether.
   */
  event CollateralWithdrawn(
    address indexed withdrawer,
    uint256 withdrawAmount,
    uint256 balanceCollateral
  );
  //functions
  /**
   * @notice Allows users to deposit Ether into the lending pool and receive LP tokens in return.
   * @dev This function is marked as `nonReentrant` to prevent reentrancy attacks. It accepts Ether deposits from the sender,
   *      updates the user's deposit balance, and increases the total liquidity of the pool. The deposit amount must be greater
   *      than zero. If the deposit amount is zero or less, the transaction is reverted with the `FinalLendingPoolContract__NotEnoughAmount` error.
   *      When the contract has zero liquidity (first deposit), the user will receive LP tokens equal to the amount they deposited.
   *      For subsequent deposits, the amount of LP tokens minted is proportional to the user's deposit compared to the total liquidity
   *      and total supply of LP tokens.
   *
   * @dev The formula used to calculate the LP tokens minted is:
   *      If the pool is empty (first deposit):
   *      `mintAmount = msg.value` (The user receives an LP token equivalent to their deposit).
   *      For subsequent deposits:
   *      `mintAmount = (msg.value * lpToken.totalSupply()) / totalLiquidity`
   *      (The LP tokens minted are proportional to the user's deposit in relation to the pool's liquidity).
   *
   * @custom:emit Deposited The event is emitted to notify listeners that funds have been successfully deposited by the user.
   */
  function depositFunds() external payable nonReentrant {
    uint256 mintAmount;
    if (msg.value <= 0) {
      revert FinalLendingPoolContract__NotEnoughAmount();
    }
    if (totalLiquidity == 0) {
      mintAmount = msg.value;
    } else {
      mintAmount = (msg.value * lpToken.totalSupply()) / totalLiquidity;
    }
    mintAmount = mintAmount / (10 ** 18);
    depositAmount[msg.sender] += msg.value;

    totalLiquidity += msg.value;
    lpToken.mint(msg.sender, mintAmount);

    emit Deposited(msg.sender, msg.value);
  }

  /**
   * @notice Allows users to deposit collateral into the lending pool.
   * @dev This function is marked as `nonReentrant` to prevent reentrancy attacks. It accepts Ether deposits from the sender
   *      and updates the user's collateral balance as well as the total collateral of the pool. The collateral amount must
   *      be greater than zero. If the amount is less than or equal to zero, the transaction is reverted with the `FinalLendingPoolContract__NotEnoughAmount` error.
   */
  function depositCollateral() external payable nonReentrant {
    if (msg.value <= 0) {
      revert FinalLendingPoolContract__NotEnoughAmount();
    }

    availableCollateralAmount[msg.sender] += msg.value;

    totalCollateral += msg.value;

    emit CollateralDeposited(msg.sender, msg.value);
  }

  /**
   * @notice Allows a user to borrow funds based on their collateral.
   * @dev The function is protected with `nonReentrant` to prevent reentrancy attacks.
   *      The requested loan amount must be denominated in USDT and adhere to the following constraints:
   *      - It must be greater than 0; otherwise, the transaction reverts with
   *        `FinalLendingPoolContract__InvalidLoanAmount`.
   *      - It must not exceed the amount available for collateralization, which is calculated
   *        using the `COLLATERALIZATION_RATIO`. If exceeded, the transaction reverts with
   *        `FinalLendingPoolContract__NotEnoughCollateral`.
   *
   * Reverts:
   * - `FinalLendingPoolContract__InvalidLoanAmount` if the requested loan amount is 0 or less.
   * - `FinalLendingPoolContract__NotEnoughCollateral` if the requested loan amount exceeds the
   *   borrower's available collateralization capacity.
   *
   * @param amount The loan amount requested by the user, denominated in USDT.
   */
  function borrowFunds(uint256 amount) external nonReentrant {
    if (amount <= 0) {
      revert FinalLendingPoolContract__InvalidLoanAmount();
    }

    uint256 collateralAvailable = availableCollateralAmount[msg.sender];

    uint256 possibleLoanAmount = (collateralAvailable *
      COLLATERALIZATION_RATIO) / 100;

    // Convert the possible loan amount in ETH to USDT using the latest ETH/USDT price
    uint256 possibleLoanAmountInUSDT = getLatestETHtoUSDTPrice(
      possibleLoanAmount
    );

    if (possibleLoanAmountInUSDT < amount) {
      revert FinalLendingPoolContract__NotEnoughCollateral();
    }

    // Calculate the required collateral in ETH for the requested loan amount (based on the collateralization ratio)
    uint256 allowedLoanAmount = getUSDTtoETHPrice(
      calculateRequiredCollateral(amount)
    );

    if (amount <= possibleLoanAmountInUSDT) {
      totalBorrowed += allowedLoanAmount;

      availableCollateralAmount[msg.sender] -= allowedLoanAmount;

      usedCollateralAmount[msg.sender] += allowedLoanAmount;

      loanCredentials[msg.sender].amountBorrowedInUSDT = amount;
      loanCredentials[msg.sender].collateralUsed = allowedLoanAmount;
      loanCredentials[msg.sender].lastUpdate = block.timestamp;

      usdtToken.transfer(msg.sender, amount);
    }
    emit LoanBorrowed(msg.sender, amount, allowedLoanAmount);
  }

  /**
   * @notice Calculates the required collateral in Ether (ETH) for a given loan amount in USDT.
   * @dev The function retrieves the latest ETH price from the Chainlink price feed and uses the
   *      `COLLATERALIZATION_RATIO` to compute the required collateral.
   *
   * Formula:
   * - Required Collateral (ETH) = (loanAmountInUSDT * 10^8 * 100) / (ETH Price * COLLATERALIZATION_RATIO)
   *
   * @param loanAmountInUSDT The loan amount for which the collateral needs to be calculated, denominated in USDT.
   * @return uint256 The amount of collateral required in Ether (ETH).
   */
  function calculateRequiredCollateral(
    uint256 loanAmountInUSDT
  ) public view returns (uint256) {
    // Fetch the latest price of ETH in USDT from the price feed
    (, int256 ethPrice, , , ) = PRICE_FEED.latestRoundData();

    // Calculate the required collateral in ETH using the loan amount and the ETH price
    // The formula takes into account the loan amount (in USDT), the ETH price (scaled by 1e8), and the collateralization ratio
    uint256 requiredCollateralInETH = (loanAmountInUSDT * 1e8 * 100) /
      (uint256(ethPrice) * COLLATERALIZATION_RATIO);

    return requiredCollateralInETH;
  }

  /**
   * @notice Retrieves the latest price of ETH in USDT.
   * @dev This function fetches the latest ETH to USDT price from the Chainlink price feed (`PRICE_FEED`).
   *      The price is multiplied by the provided `ethAmount` to calculate the equivalent value in USDT.
   *      The result is returned as the value of `ethAmount` denominated in USDT.
   * @param ethAmount The amount of Ether (ETH) to be converted into USDT.
   * @return uint256 The equivalent amount in USDT for the given `ethAmount`.
   */

  function getLatestETHtoUSDTPrice(
    uint256 ethAmount
  ) public view returns (uint256) {
    // Fetch the latest price data from the price feed, focusing on the price value
    (, int256 price, , , ) = PRICE_FEED.latestRoundData();

    // Calculate the equivalent USDT for the given ETH amount.
    // Since the price has 8 decimals, we multiply ethAmount by the price and adjust by dividing by 1e8.
    uint256 ethInUSDT = (ethAmount * uint256(price)) / 1e8;

    // Return the value in USDT, scaled accordingly to the precision
    return ethInUSDT;
  }

  /**
   * @notice Retrieves the latest price of USDT in Ether (ETH).
   * @dev This function fetches the latest price of USDT to ETH from the Chainlink price feed (`PRICE_FEED`).
   *      It then converts the provided `usdtAmount` into the equivalent amount of Ether (ETH) based on the latest price.
   * @param usdtAmount The amount of USDT to be converted into Ether (ETH).
   * @return uint256 The equivalent amount in Ether (ETH) for the given `usdtAmount`.
   */
  function getUSDTtoETHPrice(uint256 usdtAmount) public view returns (uint256) {
    // Fetch the latest round data from the price feed (returns several values, but we're interested in the price)
    (, int256 price, , , ) = PRICE_FEED.latestRoundData();

    // Calculate the equivalent amount of ETH for the given USDT amount
    // price is expected to have 8 decimals, so we multiply the USDT amount by 1e8 to match the scale.
    uint256 usdtInETH = (usdtAmount * 1e8) / uint256(price);

    return usdtInETH;
  }
  /**
   * @notice Allows a user to repay a portion or the full amount of their borrowed loan.
   * @dev The function is protected with `nonReentrant` to prevent reentrancy attacks.
   *      Users can only repay up to the amount they owe. Any attempt to repay more than the
   *      outstanding loan amount will revert the transaction with
   *      `FinalLendingPoolContract__LoanRepayLimitExceeded`.
   * @param amount The amount of USDT the user wants to repay. Must be greater than 0.
   *
   * Reverts:
   * - `FinalLendingPoolContract__NotEnoughAmount` if the repayment amount is 0 or less.
   * - `FinalLendingPoolContract__LoanRepayLimitExceeded` if the repayment amount exceeds the
   *   borrower's outstanding loan balance.
   *
   * Emits:
   * - `RepayLoan` with the borrower's address, the repayment amount, and the remaining loan balance.
   */
  // Function to allow users to repay a loan with a specified amount.
  function repayLoan(uint256 amount) external nonReentrant {
    if (amount <= 0) {
      revert FinalLendingPoolContract__NotEnoughAmount(); // Custom error thrown if repayment is zero or negative.
    }

    // Fetch the user's loan details from the mapping using their address.
    LoanDetails storage loan = loanCredentials[msg.sender];

    uint256 totalDueAmount = getTotalDebtAmountIncludingInterest(msg.sender);

    if (amount > totalDueAmount) {
      revert FinalLendingPoolContract__LoanRepayLimitExceeded();
    }

    loan.amountBorrowedInUSDT = totalDueAmount - amount;

    usdtToken.transferFrom(msg.sender, address(this), amount);

    loan.lastUpdate = block.timestamp;

    emit RepayLoan(msg.sender, amount, loan.amountBorrowedInUSDT);
  }

  /**
   * @notice Liquidates a borrower's loan if their collateral falls below the required threshold.
   * @dev This function is marked as `nonReentrant` to prevent reentrancy attacks.
   *      It retrieves the borrower's loan and collateral details, checks if the collateral value
   *      is below the liquidation threshold, and liquidates the loan by resetting the collateral and loan details.
   *
   * Liquidation Criteria:
   * - If the value of the borrower's collateral in USDT is less than the liquidation threshold, the loan is eligible for liquidation.
   * - Liquidation Threshold = (Loan Amount in USDT * COLLATERALIZATION_RATIO) / 100
   *
   * @param borrower The address of the borrower whose loan is being liquidated.
   *
   * Reverts:
   * - `FinalLendingPoolContract__NoActiveLoan`: If the borrower has no active loan or collateral.
   * - `FinalLendingPoolContract__CannotLiquidate`: If the collateral value is above or equal to the liquidation threshold.
   *
   * Emits:
   * - `Liquidated`: Emitted when the borrower's loan is successfully liquidated, logging the borrower address,
   *                 loan amount in USDT, and collateral value in USDT.
   */

  function liquidate(address borrower) external nonReentrant {
    // Retrieve the borrower's loan and collateral details
    LoanDetails storage loan = loanCredentials[borrower];
    uint256 loanAmountInUSDT = loan.amountBorrowedInUSDT;
    uint256 collateralAmountInETH = usedCollateralAmount[borrower];

    if (loanAmountInUSDT == 0 || collateralAmountInETH == 0) {
      revert FinalLendingPoolContract__NoActiveLoan();
    }

    // Get the current value of the collateral in USDT
    uint256 collateralValueInUSDT = getLatestETHtoUSDTPrice(
      collateralAmountInETH
    );

    uint256 liquidationThreshold = (loanAmountInUSDT *
      COLLATERALIZATION_RATIO) / 100;

    if (collateralValueInUSDT >= liquidationThreshold) {
      revert FinalLendingPoolContract__CannotLiquidate();
    }

    availableCollateralAmount[borrower] = 0;
    loan.amountBorrowedInUSDT = 0;

    emit Liquidated(borrower, loanAmountInUSDT, collateralValueInUSDT);
  }
  /**
   * @notice Calculates the utilization ratio of the lending pool.
   * @dev This function computes the utilization ratio by dividing the total borrowed amount by the total liquidity available in the pool. The ratio is expressed as a percentage and helps to assess how much of the pool's liquidity is being used for loans.
   * The function is internal and can only be called within the contract. It does not modify the state of the contract.
   * @return uint256 The utilization ratio, calculated as `totalBorrowed / totalLiquidity`, expressed as a percentage (scaled).
   */
  function calculateUtilizationRatio() internal view returns (uint256) {
    return totalBorrowed / totalLiquidity;
  }
  /**
   * @notice Calculates the interest rate based on the current utilization ratio.
   * @dev This function determines the interest rate by considering the base interest rate and the maximum interest rate. The interest rate is dynamically adjusted based on the utilization ratio, with higher utilization leading to a higher interest rate. The calculation uses the formula:
   * `interestRate = baseInterestRate + (maxInterestRate - baseInterestRate) * utilization`.
   * This function is internal and can only be called within the contract.
   * @return uint256 The calculated interest rate, considering the base and maximum interest rates, adjusted by the utilization ratio.
   */
  function calculateInterestRate() public view returns (uint256) {
    uint256 utilization = calculateUtilizationRatio();
    //interest rate is determined here using the utiliztion ratio
    uint256 interestRate = baseInterestRate +
      (maxInterestRate - baseInterestRate) *
      utilization;
    return interestRate;
  }
  /**
   * @notice Calculates the accrued interest for a given borrower based on the elapsed time.
   * @dev This function computes the interest accrued on the borrower's loan amount based on the current utilization ratio and interest rate.
   * The interest is calculated using the formula:
   * `interest = (loanAmount * interestRate * elapsedTime) / 100 / 365 / 24 / 60 / 60`.
   * The function considers the loan amount, interest rate, and elapsed time to return the amount of interest accrued in the specified period.
   * @param borrower The address of the borrower for whom the interest is being calculated.
   * @param elapsedTime The elapsed time (in seconds) for which the interest is to be calculated.
   * @return uint256 The total accrued interest for the borrower during the specified elapsed time period.
   */
  function calculateAccruedInterest(
    address borrower,
    uint256 elapsedTime
  ) public view returns (uint256) {
    uint256 loanAmount = loanCredentials[borrower].amountBorrowedInUSDT;
    uint256 interestRate = calculateInterestRate();
    uint256 interest = (loanAmount * interestRate * elapsedTime) /
      100 /
      365 /
      24 /
      60 /
      60;
    return interest;
  }
  /**
   * @notice Allows users to withdraw a specified Ether amount and burn a specified LP token amount for additional Ether.
   * @dev This function ensures the user has sufficient Ether deposit and LP token balance. It calculates the equivalent Ether
   *      value of the LP tokens to be burned, validates the user's balances, and processes the total withdrawal. Updates
   *      state variables and emits an event upon successful withdrawal.
   *
   * @param ethAmount The Ether amount the user wishes to withdraw from their deposit balance.
   * @param lpAmount The amount of LP tokens the user wishes to burn for additional Ether.
   *
   * @notice The transaction will revert if:
   *      - `ethAmount` and `lpAmount` are both zero.
   *      - The user has insufficient Ether deposit to cover `ethAmount`.
   *      - The user has insufficient LP tokens to burn `lpAmount`.
   *      - The Ether transfer fails.
   *
   * @custom:requirements `ethAmount` and `lpAmount` must be valid and greater than zero.
   * @custom:requirements User must have sufficient Ether deposit and LP tokens to cover the withdrawal.
   * @custom:effects Updates Ether deposit balance, LP token balance, and total liquidity.
   * @custom:emit Emits a `DepositWithdrawn` event upon successful withdrawal.
   */
  function withdrawDeposits(uint256 ethAmount, uint256 lpAmount) external {
    if (ethAmount <= 0 || lpAmount <= 0) {
      revert FinalLendingPoolContract__InvalidWithdrawalParameters();
    }
    uint256 tempLiq = totalLiquidity;

    if (ethAmount > 0) {
      if (depositAmount[msg.sender] < ethAmount) {
        revert FinalLendingPoolContract__InsufficientEtherBalance();
      }

      depositAmount[msg.sender] -= ethAmount;
      totalLiquidity -= ethAmount;
    }

    uint256 lpValueInEth = 0;
    if (lpAmount > 0) {
      uint256 lpTokenSupply = lpToken.totalSupply();
      // converting the value of lptoken to ETh
      lpValueInEth = (lpAmount * tempLiq) / lpTokenSupply;

      if (lpToken.balanceOf(msg.sender) < lpAmount) {
        revert FinalLendingPoolContract__InsufficientLPTokens();
      }
      lpToken.burn(msg.sender, lpAmount);
      totalLiquidity -= lpValueInEth;
    }

    uint256 totalWithdrawal = ethAmount + lpValueInEth;

    (bool success, ) = msg.sender.call{value: totalWithdrawal}("");
    if (!success) {
      revert FinalLendingPoolContract__WithdrawalTransactionFailed();
    }

    emit DepositWithdrawn(msg.sender, totalWithdrawal, lpAmount);
  }

  /**
   * @notice Allows users to withdraw collateral from the contract.
   * @dev Ensures the withdrawal amount is valid, the user has sufficient collateral, and the transaction succeeds.
   *      Emits the `CollateralWithdrawn` event upon successful withdrawal.
   * @param amount The amount of collateral to withdraw, denominated in Ether.
   * @custom:requirements
   * - `amount` must be greater than 0.
   * - The user must have at least `amount` available as collateral.
   * @custom:reverts
   * - `FinalLendingPoolContract__NotEnoughAmount` if `amount` is 0 or less.
   * - `FinalLendingPoolContract__WithdrawalLimitExceeded` if the user has insufficient collateral.
   * - `FinalLendingPoolContract__WithdrawalTransactionFailed` if the transaction to transfer funds fails.
   * @custom:emits Emits `CollateralWithdrawn` with the user's address, withdrawn amount, and remaining collateral.
   */
  function withdrawCollateral(uint256 amount) external {
    if (amount <= 0) {
      revert FinalLendingPoolContract__NotEnoughAmount();
    }

    uint256 collateralAvailable = availableCollateralAmount[msg.sender];

    if (amount > collateralAvailable) {
      revert FinalLendingPoolContract__WithdrawalLimitExceeded();
    }

    availableCollateralAmount[msg.sender] -= amount;
    (bool success, ) = msg.sender.call{value: amount}("");

    if (!success) {
      revert FinalLendingPoolContract__WithdrawalTransactionFailed();
    }

    emit CollateralWithdrawn(
      msg.sender,
      amount,
      availableCollateralAmount[msg.sender]
    );
  }
  /**
   * @notice Returns the deposit amount of a specified user.
   * @dev This function allows anyone to query the deposit amount of a specific user. The deposit amount is stored in the contract's state.
   * @param user The address of the user whose deposit amount is being queried.
   * @return The deposit amount of the user in the contract (in wei).
   */
  function getDepositAmount(address user) external view returns (uint256) {
    return depositAmount[user];
  }
  /**
   * @notice Returns the collateral amount of a specified user.
   * @dev This function allows anyone to query the collateral amount of a specific user. The collateral amount is stored in the contract's state.
   * @param user The address of the user whose collateral amount is being queried.
   * @return The collateral amount of the user in the contract (in wei).
   */
  function getCollateralAmount(address user) external view returns (uint256) {
    return availableCollateralAmount[user];
  }
  /**
   * @notice Calculates the current value of an LP token in Ether.
   * @dev The value of an LP token is determined by the proportion of the pool's total liquidity
   *      that each token represents. This function avoids division by zero errors and ensures
   *      accurate calculations.
   * @return The value of one LP token in Ether (Wei format). Returns 0 if no LP tokens exist.
   */
  function getCurrentLPTokenValue() public view returns (uint256) {
    uint256 lpTokenSupply = lpToken.totalSupply();
    if (lpTokenSupply == 0) {
      return 0;
    }
    return (1 ether * totalLiquidity) / lpTokenSupply;
  }
  /**
   * @notice Returns the total debt of a specified user in USDT.
   * @dev Queries the loan amount stored in the `loanCredentials` structure for the given user.
   * @param user The address of the user whose loan amount is being queried.
   * @return The total debt amount of the specified user, denominated in USDT.
   */
  function getDebt(address user) public view returns (uint256) {
    return loanCredentials[user].amountBorrowedInUSDT;
  }
  /**
   * @notice Returns the total collateral used by a specified user, denominated in ETH.
   * @dev Retrieves the `collateralUsed` value stored in the `loanCredentials` structure for the given user.
   * @param user The address of the user whose collateral amount is being queried.
   * @return The total collateral provided by the specified user in ETH.
   */
  function getDebtInETH(address user) public view returns (uint256) {
    return loanCredentials[user].collateralUsed;
  }
  /**
   * @notice Returns the total loan amount due for a specified user, including accrued interest.
   * @dev Calculates the accrued interest based on the user's borrowed amount, interest rate,
   *      and the elapsed time since the loan was last updated.
   * @param user The address of the user whose total due loan amount is being queried.
   * @return The total amount due, including principal and accrued interest, denominated in USDT.
   */

  function getTotalDebtAmountIncludingInterest(
    address user
  ) public view returns (uint256) {
    // Fetch the user's loan details from the mapping using their address.
    LoanDetails storage loan = loanCredentials[user];

    // Calculate the accrued interest based on the loan amount, interest rate, and elapsed time.
    uint256 elapsedTime = block.timestamp - loan.lastUpdate;
    uint256 accruedInterest = calculateAccruedInterest(user, elapsedTime); // Function to calculate accrued interest

    uint256 totalDueAmount = loan.amountBorrowedInUSDT + accruedInterest;
    return totalDueAmount;
  }
}
