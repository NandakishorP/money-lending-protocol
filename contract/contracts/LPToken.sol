// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
/**
 * @notice Error thrown when request comes from outside of the contract.
 */
error LPToken__AccessDenied();

/**
 * @title LPToken Contract
 * @dev This contract represents a liquidity pool (LP) token for a lending protocol.
 * It allows minting and burning of LP tokens and updates total liquidity.
 * Only the lending pool contract can call the mint, burn, and updateTotalLiquidity functions.
 */
contract LPToken is ERC20, Ownable {
  address public lendingPool; // Address of the lending pool contract
  uint256 public totalLiquidity; // Total liquidity in the pool

  /**
   * @dev Sets the name and symbol for the LP token and initializes the ERC20 contract.
   * @param name The name of the token.
   * @param symbol The symbol of the token.
   */
  constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

  /**
   * @dev Modifier that ensures only the lending pool contract can call the function.
   * Reverts with the `LPToken__AccessDenied` error if the caller is not the lending pool contract.
   */
  modifier onlyLendingPool() {
    if (msg.sender != lendingPool) {
      revert LPToken__AccessDenied();
    }
    _;
  }

  /**
   * @dev Set the address of the lending pool contract.
   * @param _lendingPool The address of the lending pool contract.
   * Can only be called by the owner of the LP token contract.
   */
  function setLendingPool(address _lendingPool) external onlyOwner {
    lendingPool = _lendingPool;
  }

  /**
   * @dev Mint LP tokens when liquidity is added to the pool.
   * Can only be called by the lending pool contract.
   * @param to The address that will receive the minted LP tokens.
   * @param amount The amount of LP tokens to mint.
   */
  function mint(address to, uint256 amount) external onlyLendingPool {
    _mint(to, amount);
  }

  /**
   * @dev Burn LP tokens when liquidity is removed from the pool.
   * Can only be called by the lending pool contract.
   * @param from The address whose LP tokens will be burned.
   * @param amount The amount of LP tokens to burn.
   */
  function burn(address from, uint256 amount) external onlyLendingPool {
    _burn(from, amount);
  }

  /**
   * @dev Update the total liquidity in the pool.
   * This is usually called by the lending pool contract to update the liquidity state.
   * @param newLiquidity The new value of total liquidity in the pool.
   */
  function updateTotalLiquidity(uint256 newLiquidity) external onlyLendingPool {
    totalLiquidity = newLiquidity;
  }
}
