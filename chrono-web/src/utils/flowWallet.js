import * as fcl from "@onflow/fcl"

export const configureFCL = () => {
  fcl.config({
    "accessNode.api": "https://rest-testnet.onflow.org", // Flow testnet
    "discovery.wallet": "https://fcl-discovery.onflow.org/testnet/authn", // Testnet wallet discovery
    "app.detail.title": "Chrono - Time Lending Protocol",
    "app.detail.icon": "https://placekitten.com/g/200/200",
  })
}

/**
 * Connect to Flow wallet
 * @returns {Promise<Object>} User account information
 */
export const connectWallet = async () => {
  try {
    const user = await fcl.authenticate()
    return user
  } catch (error) {
    console.error('Failed to connect wallet:', error)
    throw error
  }
}

export const disconnectWallet = async () => {
  try {
    await fcl.unauthenticate()
    console.log('Wallet disconnected')
  } catch (error) {
    console.error('Failed to disconnect wallet:', error)
    throw error
  }
}

/**
 * Get current user
 * @returns {Promise<Object|null>} Current user or null
 */
export const getCurrentUser = async () => {
  try {
    const user = await fcl.currentUser.snapshot()
    return user.loggedIn ? user : null
  } catch (error) {
    console.error('Failed to get current user:', error)
    return null
  }
}

/**
 * Execute a Cadence transaction
 * @param {string} code - Cadence transaction code
 * @param {Array} args - Transaction arguments
 * @returns {Promise<string>} Transaction ID
 */
export const executeTransaction = async (code, args = []) => {
  try {
    const txId = await fcl.mutate({
      cadence: code,
      args: (arg, t) => args,
      limit: 999
    })
    
    // Wait for transaction to be sealed
    const txStatus = await fcl.tx(txId).onceSealed()
    console.log('Transaction sealed:', txStatus)
    
    return txId
  } catch (error) {
    console.error('Transaction failed:', error)
    throw error
  }
}

/**
 * Execute a Cadence script (read-only)
 * @param {string} code - Cadence script code
 * @param {Array} args - Script arguments
 * @returns {Promise<any>} Script result
 */
export const executeScript = async (code, args = []) => {
  try {
    const result = await fcl.query({
      cadence: code,
      args: (arg, t) => args
    })
    return result
  } catch (error) {
    console.error('Script failed:', error)
    throw error
  }
}

/**
 * Subscribe to user authentication state changes
 * @param {Function} callback - Callback function to handle user state
 * @returns {Function} Unsubscribe function
 */
export const subscribeToUser = (callback) => {
  return fcl.currentUser.subscribe(callback)
}

/**
 * Get account balance
 * @param {string} address - Flow account address
 * @returns {Promise<string>} Account balance
 */
export const getAccountBalance = async (address) => {
  try {
    const balance = await executeScript(`
      import FlowToken from 0x7e60df042a9c0868
      import FungibleToken from 0x9a0766d93b6608b7
      
      access(all) fun main(address: Address): UFix64 {
        let account = getAccount(address)
        let vaultRef = account.capabilities
          .get<&FlowToken.Vault>(/public/flowTokenBalance)
          .borrow()
          ?? panic("Could not borrow Balance reference")
        return vaultRef.balance
      }
    `, [fcl.arg(address, fcl.t.Address)])
    
    return balance.toFixed(4)
  } catch (error) {
    console.error('Failed to fetch balance:', error)
    return '0.00'
  }
}

