import FungibleToken from 0x9a0766d93b6608b7
import IWrappedToken from 0xa6729879755d30b1

access(all) contract WrappedETH: FungibleToken, IWrappedToken {
    
    access(all) let VaultStoragePath: StoragePath
    access(all) let ReceiverPublicPath: PublicPath
    access(all) let BalancePublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath
    access(all) let BurnerStoragePath: StoragePath


    // Total supply
    access(all) var totalSupply: UFix64
    
    // Events
    access(all) event TokensInitialized(initialSupply: UFix64)
    access(all) event TokensWithdrawn(amount: UFix64, from: Address?)
    access(all) event TokensDeposited(amount: UFix64, to: Address?)
    access(all) event TokensMinted(amount: UFix64, to: Address?)
    access(all) event TokensBurned(amount: UFix64, from: Address?)
    
    // Storage paths

    
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
            let vault <- from as! @WrappedETH.Vault
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
            WrappedETH.totalSupply = WrappedETH.totalSupply + amount
            emit TokensMinted(amount: amount, to: nil)
            return <-create Vault(balance: amount)
        }
    }
    
    // Burner resource
    access(all) resource Burner: IWrappedToken.Burner {
        access(all) fun burnTokens(from: @FungibleToken.Vault) {
            let vault <- from as! @WrappedETH.Vault
            let amount = vault.balance
            WrappedETH.totalSupply = WrappedETH.totalSupply - amount
            emit TokensBurned(amount: amount, from: nil)
            destroy vault
        }
    }
    
    // Public functions
    access(all) fun createEmptyVault(vaultType: Type): @FungibleToken.Vault {
        pre {
            vaultType == Type<@WrappedETH.Vault>(): "Vault type not supported"
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
                return <-WrappedETH.createEmptyVault(vaultType: Type<@WrappedETH.Vault>())
            })
        )
    }
    
    init() {
        self.totalSupply = 0.0
        
        self.VaultStoragePath = /storage/wrappedETHVault
        self.ReceiverPublicPath = /public/wrappedETHReceiver
        self.BalancePublicPath = /public/wrappedETHBalance
        self.MinterStoragePath = /storage/wrappedETHMinter
        self.BurnerStoragePath = /storage/wrappedETHBurner
        
        // Create minter and burner for protocol use
        let minter <- create Minter()
        let burner <- create Burner()
        
        self.account.storage.save(<-minter, to: self.MinterStoragePath)
        self.account.storage.save(<-burner, to: self.BurnerStoragePath)
        
        emit TokensInitialized(initialSupply: self.totalSupply)
    }
}