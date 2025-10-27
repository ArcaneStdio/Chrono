import FungibleToken from 0x9a0766d93b6608b7
import WrappedUSDC1 from 0xe11cab85e85ae137
import TimeLendingProtocol2 from 0xe11cab85e85ae137

transaction(amount: UFix64) {

    let lenderVault: @WrappedUSDC1.Vault
    let lendingManagerRef: &TimeLendingProtocol2.LendingManager
    
    prepare(signer: auth(BorrowValue, Storage) &Account) {
        // Borrow reference to signer's USDC vault
        let vaultRef = signer.storage.borrow<auth(FungibleToken.Withdraw) &WrappedUSDC1.Vault>(
            from: WrappedUSDC1.VaultStoragePath
        ) ?? panic("Could not borrow reference to the USDC vault")

        // Withdraw USDC to lend
        self.lenderVault <- vaultRef.withdraw(amount: amount) as! @WrappedUSDC1.Vault

        // Get reference to the lending manager
        self.lendingManagerRef = TimeLendingProtocol2.borrowLendingManager()
    }
    
    execute {
        // Create lending position
        let positionId = self.lendingManagerRef.createLendingPosition(
            tokenVault: <-self.lenderVault,
            lender: self.lendingManagerRef.owner!.address
        )
        
        log("Lending position created with ID: ".concat(positionId.toString()))
    }
}