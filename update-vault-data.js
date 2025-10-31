#!/usr/bin/env node

/**
 * Script to fetch vault data from Flow blockchain and save it as JSON
 * Run: node update-vault-data.js
 */

const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');

// Configuration
const FLOW_SCRIPT_PATH = './cadence/scripts/vaultDataScript.cdc';
const OUTPUT_FILE = './chrono-web/public/vault.json';
const NETWORK = 'testnet';

/**
 * Parse the Flow script output and convert it to clean JSON
 */
function parseFlowOutput(rawOutput) {
  try {
    // Remove ANSI color codes and clean up the output
    let cleaned = rawOutput
      .replace(/\x1B\[[0-9;]*[mGKH]/g, '') // Remove ANSI codes
      .trim();

    console.log('Raw output received:', cleaned.substring(0, 200) + '...');

    // Extract vault infos array
    const vaultInfoRegex = /VaultInfo\(tokenType:\s*"([^"]+)",\s*totalDeposited:\s*([\d.]+),\s*totalBorrowed:\s*([\d.]+),\s*availableLiquidity:\s*([\d.]+),\s*utilizationRate:\s*([\d.]+),\s*numberOfActiveBorrowPositions:\s*(\d+),\s*numberOfActiveLendingPositions:\s*(\d+),\s*price:\s*([\d.]+),\s*lastPriceUpdate:\s*([\d.]+)\)/g;
    
    const vaults = [];
    let match;
    
    while ((match = vaultInfoRegex.exec(cleaned)) !== null) {
      vaults.push({
        tokenType: match[1],
        totalDeposited: parseFloat(match[2]),
        totalBorrowed: parseFloat(match[3]),
        availableLiquidity: parseFloat(match[4]),
        utilizationRate: parseFloat(match[5]),
        numberOfActiveBorrowPositions: parseInt(match[6]),
        numberOfActiveLendingPositions: parseInt(match[7]),
        price: parseFloat(match[8]),
        lastPriceUpdate: parseFloat(match[9])
      });
    }

    // Extract protocol stats
    const protocolStatsRegex = /activeLendingPositions:\s*(\d+),\s*activeBorrowingPositions:\s*(\d+),\s*unhealthyPositions:\s*(\d+),\s*overduePositions:\s*(\d+)/;
    const statsMatch = cleaned.match(protocolStatsRegex);
    
    let activeLendingPositions = 0;
    let activeBorrowingPositions = 0;
    let unhealthyPositions = 0;
    let overduePositions = 0;
    
    if (statsMatch) {
      activeLendingPositions = parseInt(statsMatch[1]);
      activeBorrowingPositions = parseInt(statsMatch[2]);
      unhealthyPositions = parseInt(statsMatch[3]);
      overduePositions = parseInt(statsMatch[4]);
    }

    // Calculate total TVL and total borrowed in USD
    let totalValueLocked = 0;
    let totalBorrowedUSD = 0;
    
    vaults.forEach(vault => {
      totalValueLocked += vault.totalDeposited * vault.price;
      totalBorrowedUSD += vault.totalBorrowed * vault.price;
    });

    const result = {
      timestamp: new Date().toISOString(),
      lastUpdate: Date.now(),
      protocolStats: {
        totalValueLocked,
        totalBorrowed: totalBorrowedUSD,
        activeLendingPositions,
        activeBorrowingPositions,
        unhealthyPositions,
        overduePositions
      },
      vaults: vaults.map(vault => ({
        ...vault,
        // Add computed fields for easy display
        totalDepositedUSD: vault.totalDeposited * vault.price,
        totalBorrowedUSD: vault.totalBorrowed * vault.price,
        availableLiquidityUSD: vault.availableLiquidity * vault.price,
        // Map token names to symbols
        symbol: getTokenSymbol(vault.tokenType),
        name: getTokenName(vault.tokenType)
      }))
    };

    return result;
  } catch (error) {
    console.error('Error parsing Flow output:', error);
    throw error;
  }
}

/**
 * Get token symbol from token type
 */
function getTokenSymbol(tokenType) {
  const symbolMap = {
    'WrappedETH': 'WETH',
    'WrappedUSDC': 'USDC',
    'FlowToken': 'FLOW'
  };
  return symbolMap[tokenType] || tokenType;
}

/**
 * Get token name from token type
 */
function getTokenName(tokenType) {
  const nameMap = {
    'WrappedETH': 'Wrapped ETH',
    'WrappedUSDC': 'USDC',
    'FlowToken': 'FLOW'
  };
  return nameMap[tokenType] || tokenType;
}

/**
 * Execute the Flow script and get vault data
 */
function fetchVaultData() {
  return new Promise((resolve, reject) => {
    const command = `flow scripts execute ${FLOW_SCRIPT_PATH} --network ${NETWORK}`;
    
    console.log(`Executing: ${command}`);
    
    exec(command, { maxBuffer: 1024 * 1024 * 10 }, (error, stdout, stderr) => {
      if (error) {
        console.error('Error executing Flow script:', error);
        console.error('stderr:', stderr);
        reject(error);
        return;
      }
      
      if (stderr) {
        console.warn('Flow script warnings:', stderr);
      }
      
      console.log('Flow script executed successfully');
      resolve(stdout);
    });
  });
}

/**
 * Main execution function
 */
async function main() {
  try {
    console.log('Starting vault data update...');
    console.log('----------------------------------------');
    
    // Fetch data from Flow
    const rawOutput = await fetchVaultData();
    
    // Parse the output
    const parsedData = parseFlowOutput(rawOutput);
    
    // Save to JSON file
    const outputPath = path.resolve(OUTPUT_FILE);
    fs.writeFileSync(outputPath, JSON.stringify(parsedData, null, 2));
    
    console.log('----------------------------------------');
    console.log('✅ Vault data updated successfully!');
    console.log(`📄 Data saved to: ${outputPath}`);
    console.log(`📊 Total vaults: ${parsedData.vaults.length}`);
    console.log(`💰 Total Value Locked: $${parsedData.protocolStats.totalValueLocked.toFixed(2)}`);
    console.log(`🏦 Active Lending Positions: ${parsedData.protocolStats.activeLendingPositions}`);
    console.log(`💸 Active Borrowing Positions: ${parsedData.protocolStats.activeBorrowingPositions}`);
    console.log('----------------------------------------');
    
    // Display vault summary
    console.log('\nVault Summary:');
    parsedData.vaults.forEach(vault => {
      console.log(`  ${vault.symbol}:`);
      console.log(`    - Deposited: ${vault.totalDeposited.toFixed(2)} (${vault.totalDepositedUSD.toFixed(2)} USD)`);
      console.log(`    - Borrowed: ${vault.totalBorrowed.toFixed(2)} (${vault.totalBorrowedUSD.toFixed(2)} USD)`);
      console.log(`    - Utilization: ${vault.utilizationRate.toFixed(2)}%`);
    });
    
  } catch (error) {
    console.error('❌ Failed to update vault data:', error.message);
    process.exit(1);
  }
}

// Run the script
if (require.main === module) {
  main();
}

module.exports = { parseFlowOutput, fetchVaultData };






