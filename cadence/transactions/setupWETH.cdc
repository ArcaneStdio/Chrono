import FungibleToken from 0x9a0766d93b6608b7
import WrappedETH from 0x695362a431cd594b

transaction() {
    
    prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, PublishCapability, SaveValue, UnpublishCapability) &Account) {
        // Check if vault already exists
        if signer.storage.borrow<&WrappedETH.Vault>(from: WrappedETH.VaultStoragePath) != nil {
            return
        }
        
        // Create a new empty vault
        let vault <- WrappedETH.createEmptyVault(vaultType: Type<@WrappedETH.Vault>())
        
        // Save the vault to storage
        signer.storage.save(<-vault, to: WrappedETH.VaultStoragePath)
        
        // Create and publish public capabilities
        
        // Receiver capability
        let receiverCap = signer.capabilities.storage.issue<&{FungibleToken.Receiver}>(
            WrappedETH.VaultStoragePath
        )
        signer.capabilities.publish(receiverCap, at: WrappedETH.ReceiverPublicPath)
        
        // Balance capability
        let balanceCap = signer.capabilities.storage.issue<&{FungibleToken.Balance}>(
            WrappedETH.VaultStoragePath
        )
        signer.capabilities.publish(balanceCap, at: WrappedETH.BalancePublicPath)
    }
    
    execute {
        log("WrappedETH vault setup complete")
    }
}