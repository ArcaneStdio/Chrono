import * as fcl from "@onflow/fcl";
import * as t from "@onflow/types";
import { executeTransaction } from './flowWallet'; // Assuming your FCL utilities are here

/**
 * Creates a new Time Lending Borrowing Position using WETH as collateral to borrow USDC.
 * It also handles the FLOW payment for the Band Oracle fee.
 * * @param {string} collateralAmount - Amount of Wrapped ETH to deposit (e.g., "10.0").
 * @param {string} borrowAmount - Amount of Wrapped USDC to borrow (e.g., "500.0").
 * @param {string} durationMinutes - Duration of the loan in minutes (must be a string representing an integer, e.g., "1440").
 * @returns {Promise<string>} The transaction ID.
 */
export const createBorrowingPosition = async (
    collateralAmount, 
    borrowAmount, 
    durationMinutes
) => {
    // The complete Cadence transaction code as a string
    const createBorrowingCadence = `
        import FungibleToken from 0x9a0766d93b6608b7
        import FlowToken from 0x7e60df042a9c0868
        import TimeLendingProtocol2 from 0xe11cab85e85ae137
        import WrappedETH1 from 0xe11cab85e85ae137
        import WrappedUSDC1 from 0xe11cab85e85ae137
        import BandOracle from 0x9fb6606c300b5051

        // Transaction to borrow USDC using Wrapped ETH as collateral
        transaction(
            collateralAmount: UFix64,      
            borrowAmount: UFix64,          
            durationMinutes: UInt64        
        ) {
            
            let borrowingManagerRef: &TimeLendingProtocol2.BorrowingManager
            let collateralVault: @{FungibleToken.Vault}
            let borrowedTokensReceiver: &{FungibleToken.Receiver}
            let oraclePayment: @{FungibleToken.Vault}
            let signerAddress: Address
            
            prepare(signer: auth(BorrowValue, Storage, Capabilities) &Account) {
                // Check the Cadence 1.0 migration guide for the latest syntax updates: https://cadence-lang.org/docs/cadence-migration-guide/improvements

                self.signerAddress = signer.address
                
                // Get reference to the borrowing manager
                self.borrowingManagerRef = TimeLendingProtocol2.borrowBorrowingManager()
                
                // Withdraw Wrapped ETH collateral from signer's vault
                let wrappedETHVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &{FungibleToken.Vault}>(
                    from: WrappedETH1.VaultStoragePath
                ) ?? panic("Could not borrow Wrapped ETH vault from storage. Make sure you have WrappedETH1 vault set up.")
                
                self.collateralVault <- wrappedETHVault.withdraw(amount: collateralAmount)
                
                // Get receiver capability for borrowed USDC tokens
                self.borrowedTokensReceiver = signer.capabilities.get<&{FungibleToken.Receiver}>(
                    WrappedUSDC1.ReceiverPublicPath
                ).borrow() ?? panic("Could not borrow USDC receiver capability. Make sure you have WrappedUSDC1 vault set up.")
                
                // Withdraw FLOW tokens for oracle payment
                let flowVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
                    from: /storage/flowTokenVault
                ) ?? panic("Could not borrow FLOW vault from storage")
                
                // NOTE: BandOracle.getFee() is a public constant or function called on-chain during execution.
                self.oraclePayment <- flowVault.withdraw(amount: BandOracle.getFee())
            }
            
            execute {
                // Create borrowing position with correct WrappedUSDC1 type
                let positionId = self.borrowingManagerRef.createBorrowingPosition(
                    collateralVault: <- self.collateralVault,
                    borrowTokenType: Type<@WrappedUSDC1.Vault>(),
                    borrowAmount: borrowAmount,
                    durationMinutes: durationMinutes,
                    borrower: self.signerAddress,
                    borrowerRecipient: self.borrowedTokensReceiver,
                    oraclePayment: <- self.oraclePayment
                )
                
                if positionId == nil {
                    panic("Failed to create borrowing position - borrow amount exceeds LTV limit")
                }
                
                log("Successfully created borrowing position with ID: ".concat(positionId!.toString()))
            }
        }
    `;

    // 2. Construct the FCL Arguments array with correct types
    const transactionArgs = [
        // Arg 1: collateralAmount (UFix64)
        fcl.arg((parseFloat(collateralAmount).toFixed(8), fcl.t.UFix64)),
        // Arg 2: borrowAmount (UFix64)
        fcl.arg((parseFloat(borrowAmount).toFixed(8), fcl.t.UFix64)),
        // Arg 3: durationMinutes (UInt64)
        fcl.arg(durationMinutes, fcl.t.UInt64),
    ];

    // 3. Execute the transaction using your utility function
    // Your utility handles the fcl.mutate call and waits for the status.
    const txId = await executeTransaction(createBorrowingCadence, transactionArgs);
    
    return txId;
}