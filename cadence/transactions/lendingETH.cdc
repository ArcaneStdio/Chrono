import FungibleToken from 0x9a0766d93b6608b7
import WrappedETH1 from 0xe11cab85e85ae137
import TimeLendingProtocol2 from 0xe11cab85e85ae137

transaction(amount: UFix64) {
    
    let lenderVault: @WrappedETH1.Vault
    let lendingManagerRef: &TimeLendingProtocol2.LendingManager
    
    prepare(signer: auth(BorrowValue, Storage) &Account) {
        // Borrow reference to signer's ETH vault
        let vaultRef = signer.storage.borrow<auth(FungibleToken.Withdraw) &WrappedETH1.Vault>(
            from: WrappedETH1.VaultStoragePath
        ) ?? panic("Could not borrow reference to the ETH vault")
        
        // Withdraw ETH to lend
        self.lenderVault <- vaultRef.withdraw(amount: amount) as! @WrappedETH1.Vault
        
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