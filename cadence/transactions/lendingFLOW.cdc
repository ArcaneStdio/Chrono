import FungibleToken from 0x9a0766d93b6608b7
import FlowToken from 0x7e60df042a9c0868
import TimeLendingProtocol2 from 0xe11cab85e85ae137

transaction(amount: UFix64) {
    
    let lenderVault: @FlowToken.Vault
    let lendingManagerRef: &TimeLendingProtocol2.LendingManager
    
    prepare(signer: auth(BorrowValue, Storage) &Account) {
        // Borrow reference to signer's FLOW vault
        let vaultRef = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
            from: /storage/flowTokenVault
        ) ?? panic("Could not borrow reference to the FLOW vault")
        
        // Withdraw FLOW to lend
        self.lenderVault <- vaultRef.withdraw(amount: amount) as! @FlowToken.Vault
        
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

