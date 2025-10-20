// Interface for wrapped tokens representing currencies from other chains
import FungibleToken from 0xee82856bf20e2aa6


access(all) contract interface IWrappedToken {
    
    // Events
    access(all) event TokensMinted(amount: UFix64, to: Address?)
    access(all) event TokensBurned(amount: UFix64, from: Address?)
    
    // Core token functionality
    access(all) resource interface Provider {
        access(all) fun withdraw(amount: UFix64): @{FungibleToken.Vault}
    }
    
    access(all) resource interface Receiver {
        access(all) fun deposit(from: @{FungibleToken.Vault})
    }
    
    access(all) resource interface Balance {
        access(all) var balance: UFix64
    }
    
    // Vault resource that implements FungibleToken.Vault
    //! Removed inheritance from FungibleToken.Vault because it gave error that function with same name defined there
    access(all) resource interface Vault: Provider, Receiver, Balance {
        access(all) var balance: UFix64
        
        access(all) fun withdraw(amount: UFix64): @{FungibleToken.Vault} {
            pre {
                self.balance >= amount: "Insufficient balance"
            }
        }
        
        access(all) fun deposit(from: @{FungibleToken.Vault}) {
            pre {
                from.getType() == self.getType(): "Token types do not match"
            }
        }
    }
    
    // Minter resource for protocol use
    access(all) resource interface Minter {
        access(all) fun mintTokens(amount: UFix64): @{FungibleToken.Vault}
    }
    
    // Burner resource for protocol use
    access(all) resource interface Burner {
        access(all) fun burnTokens(from: @{FungibleToken.Vault})
    }
}