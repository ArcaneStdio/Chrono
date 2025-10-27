import FungibleToken from 0x9a0766d93b6608b7
import FlowToken from 0x7e60df042a9c0868
import TimeLendingProtocol2 from 0xa6729879755d30b1
import IWrappedToken from 0xa6729879755d30b1

// Transaction to borrow USDC using Wrapped ETH as collateral
transaction(
    collateralAmount: UFix64,      // Amount of Wrapped ETH to use as collateral
    borrowAmount: UFix64,           // Amount of USDC to borrow
    durationMinutes: UInt64,        // Duration of the loan in minutes
    oraclePaymentAmount: UFix64     // Amount of FLOW to pay for oracle price update (typically 0.01)
) {
    
    let borrowingManagerRef: &TimeLendingProtocol2.BorrowingManager
    let collateralVault: @{FungibleToken.Vault}
    let borrowedTokensReceiver: &{FungibleToken.Receiver}
    let oraclePayment: @{FungibleToken.Vault}
    let signerAddress: Address
    
    prepare(signer: auth(BorrowValue, Storage) &Account) {
        self.signerAddress = signer.address
        
        // Get reference to the borrowing manager
        self.borrowingManagerRef = TimeLendingProtocol2.borrowBorrowingManager()
        
        // Withdraw Wrapped ETH collateral from signer's vault
        // Adjust the storage path based on your Wrapped ETH implementation
        let wrappedETHVaultPath = /storage/wrappedETHVault
        
        let wrappedETHVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &{FungibleToken.Vault}>(
            from: wrappedETHVaultPath
        ) ?? panic("Could not borrow Wrapped ETH vault from storage")
        
        self.collateralVault <- wrappedETHVault.withdraw(amount: collateralAmount)
        
        // Get receiver capability for borrowed USDC tokens
        // Adjust the path based on your USDC implementation
        let usdcReceiverPath = /public/wrappedUSDCReceiver
        
        self.borrowedTokensReceiver = signer.capabilities.get<&{FungibleToken.Receiver}>(usdcReceiverPath).borrow()
            ?? panic("Could not borrow USDC receiver capability")
        
        // Withdraw FLOW tokens for oracle payment
        let flowVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
            from: /storage/flowTokenVault
        ) ?? panic("Could not borrow FLOW vault from storage")
        
        self.oraclePayment <- flowVault.withdraw(amount: oraclePaymentAmount)
    }
    
    execute {
        // Create borrowing position
        let positionId = self.borrowingManagerRef.createBorrowingPosition(
            collateralVault: <- self.collateralVault,
            borrowTokenType: Type<@IWrappedToken.WrappedUSDC.Vault>(),  // Adjust based on your USDC type
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