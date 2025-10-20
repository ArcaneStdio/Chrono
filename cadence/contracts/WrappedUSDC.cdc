import FungibleToken from 0xf233dcee88fe0abe
import IWrappedToken from "./IWrappedToken.cdc"

access(all) contract WrappedUSDC: FungibleToken, IWrappedToken {
    
    // Total supply
    access(all) var totalSupply: UFix64
    
    // Events
    access(all) event TokensInitialized(initialSupply: UFix64)
    access(all) event TokensWithdrawn(amount: UFix64, from: Address?)
    access(all) event TokensDeposited(amount: UFix64, to: Address?)
    access(all) event TokensMinted(amount: UFix64, to: Address?)
    access(all) event TokensBurned(amount: UFix64, from: Address?)
    
    // Storage paths
    access(all) let VaultStoragePath: StoragePath
    access(all) let ReceiverPublicPath: PublicPath
    access(all) let BalancePublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath
    access(all) let BurnerStoragePath: StoragePath
    
    // Vault implementation
    access(all) resource Vault: FungibleToken.Vault, IWrappedToken.Provider, IWrappedToken.Receiver, IWrappedToken.Balance {
        access(all) var balance: UFix64
        
        init(balance: UFix64) {
            self.balance = balance
        }
        
        access(all) fun withdraw(amount: UFix64): @FungibleToken.Vault {
            pre {
                self.balance >= amount: "Insufficient balance"
            }
            self.balance = self.balance - amount
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            return <-create Vault(balance: amount)
        }
        
        access(all) fun deposit(from: @FungibleToken.Vault) {
            let vault <- from as! @WrappedUSDC.Vault
            self.balance = self.balance + vault.balance
            emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
            vault.balance = 0.0
            destroy vault
        }
        
        access(all) view fun getBalance(): UFix64 {
            return self.balance
        }
        
        access(all) view fun getSupportedVaultTypes(): {Type: Bool} {
            return {self.getType(): true}
        }
        
        access(all) view fun isSupportedVaultType(type: Type): Bool {
            return type == self.getType()
        }
        
        access(all) fun createEmptyVault(): @FungibleToken.Vault {
            return <-create Vault(balance: 0.0)
        }
    }
    
    // Minter resource
    access(all) resource Minter: IWrappedToken.Minter {
        access(all) fun mintTokens(amount: UFix64): @FungibleToken.Vault {
            pre {
                amount > 0.0: "Amount must be positive"
            }
            WrappedUSDC.totalSupply = WrappedUSDC.totalSupply + amount
            emit TokensMinted(amount: amount, to: nil)
            return <-create Vault(balance: amount)
        }
    }
    
    // Burner resource
    access(all) resource Burner: IWrappedToken.Burner {
        access(all) fun burnTokens(from: @FungibleToken.Vault) {
            let vault <- from as! @WrappedUSDC.Vault
            let amount = vault.balance
            WrappedUSDC.totalSupply = WrappedUSDC.totalSupply - amount
            emit TokensBurned(amount: amount, from: nil)
            destroy vault
        }
    }
    
    // Public functions
    access(all) fun createEmptyVault(vaultType: Type): @FungibleToken.Vault {
        pre {
            vaultType == Type<@WrappedUSDC.Vault>(): "Vault type not supported"
        }
        return <-create Vault(balance: 0.0)
    }
    
    access(all) view fun getVaultTypeData(): FungibleToken.VaultData {
        return FungibleToken.VaultData(
            storagePath: self.VaultStoragePath,
            receiverPath: self.ReceiverPublicPath,
            metadataPath: self.BalancePublicPath,
            receiverLinkedType: Type<&FungibleToken.Receiver>(),
            metadataLinkedType: Type<&FungibleToken.Balance>(),
            createEmptyVaultFunction: (fun(): @FungibleToken.Vault {
                return <-WrappedUSDC.createEmptyVault(vaultType: Type<@WrappedUSDC.Vault>())
            })
        )
    }
    
    init() {
        self.totalSupply = 0.0
        
        self.VaultStoragePath = /storage/wrappedUSDCVault
        self.ReceiverPublicPath = /public/wrappedUSDCReceiver
        self.BalancePublicPath = /public/wrappedUSDCBalance
        self.MinterStoragePath = /storage/wrappedUSDCMinter
        self.BurnerStoragePath = /storage/wrappedUSDCBurner
        
        // Create minter and burner for protocol use
        let minter <- create Minter()
        let burner <- create Burner()
        
        self.account.storage.save(<-minter, to: self.MinterStoragePath)
        self.account.storage.save(<-burner, to: self.BurnerStoragePath)
        
        emit TokensInitialized(initialSupply: self.totalSupply)
    }
}