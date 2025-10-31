import * as fcl from "@onflow/fcl";
import { executeTransaction } from './flowWallet'; // Assuming your FCL utilities are here

/**
 * Creates a new Time Lending Position by depositing WETH into the protocol.
 * @param {string} amount - The amount of Wrapped ETH to lend (e.g., "10.0").
 * @returns {Promise<string>} The transaction ID.
 */
export const createLendingPosition = async (amount) => {
  // Your Cadence transaction code as a string
  // NOTE: We must use the fcl.t.UFix64 type for the amount.
  const createLendingCadence = `
    import FungibleToken from 0x9a0766d93b6608b7
    import WrappedETH1 from 0xe11cab85e85ae137
    import TimeLendingProtocol2 from 0xe11cab85e85ae137

    transaction(amount: UFix64) {
        
        let lenderVault: @WrappedETH1.Vault 
        let lendingManagerRef: &TimeLendingProtocol2.LendingManager
        let signer: Address

        
        prepare(signer: auth(BorrowValue, Storage) &Account) {
            // Check the Cadence 1.0 migration guide for the latest syntax updates: https://cadence-lang.org/docs/cadence-migration-guide/improvements
            // Note: The 'auth(BorrowValue, Storage)' is a capability-based authorization that your contract likely requires.
            
            self.signer = signer.address
            // Borrow reference to signer's ETH vault
            let vaultRef = signer.storage.borrow<auth(FungibleToken.Withdraw) &WrappedETH1.Vault>(
                from: WrappedETH1.VaultStoragePath
            ) ?? panic("Could not borrow reference to the ETH vault")
            
            // Withdraw ETH to lend
            self.lenderVault <- vaultRef.withdraw(amount: amount) as! @WrappedETH1.Vault
            
            // Get reference to the lending manager
            // Note: If borrowLendingManager is a private function, this will fail. It must be accessible.
            self.lendingManagerRef = TimeLendingProtocol2.borrowLendingManager()
        }
        
        execute {
            // Create lending position
            let positionId = self.lendingManagerRef.createLendingPosition(
                tokenVault: <-self.lenderVault,
                lender: self.signer
            )
            
            log("Lending position created with ID: ".concat(positionId.toString()))
        }
    }
  `;

  // 1. Convert the JavaScript amount string/number into an FCL Argument object
  const transactionArgs = [
    // The amount must be a UFix64, which FCL handles by providing 't.UFix64'
    fcl.arg(parseFloat(amount).toFixed(8), fcl.t.UFix64),
  ];

  // 2. Execute the transaction using your utility function
  // Your utility handles the fcl.mutate call and waits for the status.
  const txId = await executeTransaction(createLendingCadence, transactionArgs);
  
  return txId;
}