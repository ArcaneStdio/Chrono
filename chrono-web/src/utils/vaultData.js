const VAULT_DATA_PATH = '/vault.json';

/**
 * Fetch the latest vault data from the JSON file
 * @returns {Promise<Object>} Parsed vault data
 */
export async function fetchVaultData() {
  try {
    // In production, this will be served from the public directory
    // During development, make sure vault.json is in the public folder
    const response = await fetch(VAULT_DATA_PATH + '?t=' + Date.now());
    
    if (!response.ok) {
      throw new Error(`Failed to fetch vault data: ${response.status}`);
    }
    
    const data = await response.json();
    return data;
  } catch (error) {
    console.error('Error fetching vault data:', error);
    throw error;
  }
}

export function formatUSD(value) {
  if (value >= 1e9) {
    return `$${(value / 1e9).toFixed(2)}B`;
  }
  if (value >= 1e6) {
    return `$${(value / 1e6).toFixed(2)}M`;
  }
  if (value >= 1e3) {
    return `$${(value / 1e3).toFixed(2)}K`;
  }
  return `$${value.toFixed(2)}`;
}

export function formatTokenAmount(value, symbol, decimals = 2) {
  if (value >= 1e6) {
    return `${(value / 1e6).toFixed(decimals)}M ${symbol}`;
  }
  if (value >= 1e3) {
    return `${(value / 1e3).toFixed(decimals)}K ${symbol}`;
  }
  return `${value.toFixed(decimals)} ${symbol}`;
}

/**
 * Calculate borrow APY based on utilization rate
 * TODO: This is a placeholder
 */
export function calculateBorrowAPY(utilizationRate) {
  // Simple linear model: APY = baseRate + utilizationRate * multiplier
  const baseRate = 2.0;
  const multiplier = 0.1;
  return (baseRate + utilizationRate * multiplier).toFixed(2) + '%';
}

/**
 * Calculate supply APY based on borrow APY and utilization
 */
export function calculateSupplyAPY(borrowAPY, utilizationRate) {
  const borrowRate = parseFloat(borrowAPY);
  const utilization = utilizationRate / 100;
  return (borrowRate * utilization * 0.9).toFixed(2) + '%'; // 90% goes to suppliers
}

/**
 * Get vault by token symbol
 */
export function getVaultBySymbol(vaults, symbol) {
  return vaults.find(vault => vault.symbol === symbol);
}

/**
 * Check if vault data is stale (older than 4 hours)
 */
export function isDataStale(timestamp) {
  const dataAge = Date.now() - new Date(timestamp).getTime();
  const fourHours = 4 * 60 * 60 * 1000;
  return dataAge > fourHours;
}

/**
 * Transform vault data for the Lend view
 */
export function transformForLendView(vaultData) {
  if (!vaultData || !vaultData.vaults) {
    return [];
  }

  return vaultData.vaults.map(vault => {
    const borrowAPY = calculateBorrowAPY(vault.utilizationRate);
    const supplyAPY = calculateSupplyAPY(borrowAPY, vault.utilizationRate);
    
    return {
      name: vault.name,
      symbol: vault.symbol,
      protocol: 'Chrono',
      supplyAPY: supplyAPY,
      totalSupply: formatUSD(vault.totalDepositedUSD),
      totalSupplyToken: formatTokenAmount(vault.totalDeposited, vault.symbol),
      exposure: vault.numberOfActiveBorrowPositions,
      utilization: vault.utilizationRate.toFixed(2) + '%',
      utilizationPercent: vault.utilizationRate,
      // Additional data for detail view
      totalBorrowed: formatUSD(vault.totalBorrowedUSD),
      availableLiquidity: formatUSD(vault.availableLiquidityUSD),
      borrowAPY: borrowAPY,
      price: vault.price
    };
  });
}

/**
 * Transform vault data for the Borrow view
 */
export function transformForBorrowView(vaultData) {
  if (!vaultData || !vaultData.vaults) {
    return [];
  }

  return vaultData.vaults
    .filter(vault => vault.availableLiquidity > 0) // Only show vaults with liquidity
    .map(vault => {
      const borrowAPY = calculateBorrowAPY(vault.utilizationRate);
      
      return {
        name: vault.name,
        symbol: vault.symbol,
        protocol: 'Chrono',
        borrowAPY: borrowAPY,
        available: formatUSD(vault.availableLiquidityUSD),
        availableToken: formatTokenAmount(vault.availableLiquidity, vault.symbol),
        maxLTV: '75%', 
        liquidationThreshold: '85%',
        // Additional data
        price: vault.price,
        utilization: vault.utilizationRate
      };
    });
}

/**
 * Get protocol-wide statistics
 */
export function getProtocolStats(vaultData) {
  if (!vaultData || !vaultData.protocolStats) {
    return null;
  }

  const stats = vaultData.protocolStats;
  
  return {
    totalValueLocked: formatUSD(stats.totalValueLocked),
    totalBorrowed: formatUSD(stats.totalBorrowed),
    activeLendingPositions: stats.activeLendingPositions,
    activeBorrowingPositions: stats.activeBorrowingPositions,
    unhealthyPositions: stats.unhealthyPositions,
    overduePositions: stats.overduePositions,
    lastUpdate: vaultData.timestamp
  };
}

