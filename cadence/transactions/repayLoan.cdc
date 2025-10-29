import FungibleToken from 0x9a0766d93b6608b7
import TimeLendingProtocol2 from 0xe11cab85e85ae137
import WrappedETH1 from 0xe11cab85e85ae137
import WrappedUSDC1 from 0xe11cab85e85ae137

// Transaction to repay a loan and retrieve collateral
// Repays the borrowed amount + interest and returns the collateral to the borrower

transaction(positionId: UInt64) {
    
    let borrowingManagerRef: &TimeLendingProtocol2.BorrowingManager
    let repaymentVault: @{FungibleToken.Vault}
    let collateralRecipient: &{FungibleToken.Receiver}
    let position: TimeLendingProtocol2.BorrowingPosition
    let totalRepayment: UFix64
    let borrowerAuth: auth(Storage) &Account
    
    prepare(signer: auth(BorrowValue, Storage, Capabilities) &Account) {
        // Get the borrowing position to check details
        self.position = TimeLendingProtocol2.getBorrowingPosition(id: positionId)
            ?? panic("Position does not exist")
        
        if !self.position.isActive {
            panic("Position is not active")
        }
        self.borrowerAuth = signer
        
        // Get reference to the borrowing manager
        self.borrowingManagerRef = TimeLendingProtocol2.borrowBorrowingManager()
        
        // Calculate total repayment (principal + interest)
        let timeElapsed = getCurrentBlock().timestamp - self.position.timestamp
        let protocolParams = TimeLendingProtocol2.getProtocolParameters()
        let annualRate = protocolParams["baseInterestRate"] as! UFix64
        let interest = self.position.borrowAmount * annualRate * timeElapsed / 31536000.0
        self.totalRepayment = self.position.borrowAmount + interest
        
        log("Loan Details:")
        log("  Position ID: ".concat(positionId.toString()))
        log("  Principal: ".concat(self.position.borrowAmount.toString()))
        log("  Interest: ".concat(interest.toString()))
        log("  Total Repayment: ".concat(self.totalRepayment.toString()))
        log("  Time Elapsed: ".concat(timeElapsed.toString()).concat(" seconds"))
        
        // Determine which token vault to use for repayment
        let borrowTokenType = self.position.borrowTokenType
        
        // Withdraw repayment tokens based on borrow token typ
            // Repaying USDC loan
            let usdcVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &{FungibleToken.Vault}>(
                from: WrappedUSDC1.VaultStoragePath
            ) ?? panic("Could not borrow WrappedUSDC vault from storage")
            
            self.repaymentVault <- usdcVault.withdraw(amount: self.totalRepayment)
        
        // Setup collateral recipient based on collateral type
        let collateralType = self.position.collateralType
    
            // Receiving ETH collateral back
            self.collateralRecipient = signer.capabilities.get<&{FungibleToken.Receiver}>(
                WrappedETH1.ReceiverPublicPath
            ).borrow() ?? panic("Could not borrow WrappedETH receiver capability")
    }

    execute {
        // Repay the loan
        self.borrowingManagerRef.repayLoan(
            positionId: positionId,
            repaymentVault: <- self.repaymentVault,
            collateralRecipient: self.collateralRecipient,
            borrowerAuth: self.borrowerAuth
        )
        
        log("✅ Loan successfully repaid!")
        log("  Total paid: ".concat(self.totalRepayment.toString()))
        log("  Collateral returned: ".concat(self.position.collateralAmount.toString()))
        log("  Position closed: #".concat(positionId.toString()))
    }
}