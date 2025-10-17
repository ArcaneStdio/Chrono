import "FungibleToken"

/// This contract implements the FungibleToken interface to create a wrapped token.
///
access(all) contract WrappedToken: FungibleToken {

    // The total supply of the token
    access(all) var totalSupply: UFix64

    // The path where the Vault is stored
    access(all) let vaultStoragePath: StoragePath

    // The path where the Receiver is published
    access(all) let receiverPublicPath: PublicPath

    // The path where the Minter is stored
    access(all) let minterStoragePath: StoragePath

    /// The Vault resource that holds the tokens
    access(all) resource Vault: FungibleToken.Vault {
        access(all) var balance: UFix64

        init(balance: UFix64) {
            self.balance = balance
        }

        access(all) fun withdraw(amount: UFix64): @FungibleToken.Vault {
            self.balance = self.balance - amount
            return <-create Vault(balance: amount)
        }

        access(all) fun deposit(from: @FungibleToken.Vault) {
            let vault <- from as! @WrappedToken.Vault
            self.balance = self.balance + vault.balance
            destroy vault
        }
    }

    /// Creates an empty Vault
    access(all) fun createEmptyVault(): @FungibleToken.Vault {
        return <-create Vault(balance: 0.0)
    }

    /// The Minter resource that can mint new tokens
    access(all) resource Minter {
        access(all) fun mint(amount: UFix64, recipient: Capability<&{FungibleToken.Receiver}>) {
            let recipientRef = recipient.borrow() ?? panic("Could not borrow receiver reference")
            let newVault <- create Vault(balance: amount)
            WrappedToken.totalSupply = WrappedToken.totalSupply + amount
            recipientRef.deposit(from: <-newVault)
        }
    }

    init() {
        self.totalSupply = 0.0
        self.vaultStoragePath = /storage/wrappedTokenVault
        self.receiverPublicPath = /public/wrappedTokenReceiver
        self.minterStoragePath = /storage/wrappedTokenMinter
        let minter <- create Minter()
        self.account.storage.save(<-minter, to: self.minterStoragePath)
    }
}