import FungibleToken from 0x9a0766d93b6608b7
import FlowToken from 0x7e60df042a9c0868
import TimeLendingProtocol2 from 0x904a8cd375b62ddc
import WrappedETH1 from 0xe11cab85e85ae137
import WrappedUSDC1 from 0xe11cab85e85ae137
import BandOracle from 0x9fb6606c300b5051

// Transaction to borrow USDC using Wrapped ETH as collateral
transaction(
    collateralAmount: UFix64,      // Amount of Wrapped ETH to use as collateral
    borrowAmount: UFix64,           // Amount of USDC to borrow
    durationMinutes: UInt64         // Duration of the loan in minutes
) {
    
    let borrowingManagerRef: &TimeLendingProtocol2.BorrowingManager
    let collateralVault: @{FungibleToken.Vault}
    let borrowedTokensReceiver: &{FungibleToken.Receiver}
    let oraclePayment1: @{FungibleToken.Vault}
    let oraclePayment2: @{FungibleToken.Vault}
    let signerAddress: Address
    
    prepare(signer: auth(BorrowValue, Storage, Capabilities) &Account) {
        self.signerAddress = signer.address
        
        // Get reference to the borrowing manager
        self.borrowingManagerRef = TimeLendingProtocol2.borrowBorrowingManager()
        
        // Withdraw Wrapped ETH collateral from signer's vault using WrappedETH1 paths
        let wrappedETHVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &{FungibleToken.Vault}>(
            from: WrappedETH1.VaultStoragePath
        ) ?? panic("Could not borrow Wrapped ETH vault from storage. Make sure you have WrappedETH1 vault set up.")
        
        self.collateralVault <- wrappedETHVault.withdraw(amount: collateralAmount)
        
        // Get receiver capability for borrowed USDC tokens using WrappedUSDC1 paths
        self.borrowedTokensReceiver = signer.capabilities.get<&{FungibleToken.Receiver}>(
            WrappedUSDC1.ReceiverPublicPath
        ).borrow() ?? panic("Could not borrow USDC receiver capability. Make sure you have WrappedUSDC1 vault set up.")
        
        // Withdraw FLOW tokens for oracle payment using BandOracle fee
        let flowVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
            from: /storage/flowTokenVault
        ) ?? panic("Could not borrow FLOW vault from storage")
        
        self.oraclePayment1 <- flowVault.withdraw(amount: BandOracle.getFee())
        self.oraclePayment2 <- flowVault.withdraw(amount: BandOracle.getFee())
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
            oraclePayment1: <- self.oraclePayment1,
            oraclePayment2: <- self.oraclePayment2
        )
        
        if positionId == nil {
            panic("Failed to create borrowing position - borrow amount exceeds LTV limit")
        }
        
        log("Successfully created borrowing position with ID: ".concat(positionId!.toString()))
        log("Collateral locked: ".concat(collateralAmount.toString()).concat(" WrappedETH"))
        log("Borrowed: ".concat(borrowAmount.toString()).concat(" WrappedUSDC"))
        log("Duration: ".concat(durationMinutes.toString()).concat(" minutes"))
    }
}