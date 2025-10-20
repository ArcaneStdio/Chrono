import "FungibleToken"

/// A vault for holding collateral.
///
access(all) contract CollateralVault {

    /// The Vault resource for holding collateral
    access(all) resource Vault {
        access(all) let tokenType: Type
        access(all) var balance: UFix64
        access(self) let vault: @FungibleToken.Vault

        init(from: @FungibleToken.Vault) {
            self.tokenType = from.getType()
            self.balance = from.balance
            self.vault <- from
        }

        /// Withdraw collateral
        access(all) fun withdraw(amount: UFix64): @FungibleToken.Vault {
            self.balance = self.balance - amount
            return <-self.vault.withdraw(amount: amount)
        } 
    }

    /// Create a new collateral vault
    access(all) fun createVault(from: @FungibleToken.Vault): @Vault {
        return <-create Vault(from: <-from)
    }
}