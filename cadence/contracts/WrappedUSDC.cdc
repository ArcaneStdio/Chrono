import FungibleToken from 0x9a0766d93b6608b7
import MetadataViews from 0x631e88ae7f1d7c20
import FungibleTokenMetadataViews from 0x9a0766d93b6608b7

access(all) contract WrappedUSDC1: FungibleToken {
    
    access(all) let VaultStoragePath: StoragePath
    access(all) let VaultPublicPath: PublicPath
    access(all) let ReceiverPublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath
    access(all) let BurnerStoragePath: StoragePath

    access(all) var totalSupply: UFix64
    
    // Events
    access(all) event TokensInitialized(initialSupply: UFix64)
    access(all) event TokensWithdrawn(amount: UFix64, from: Address?)
    access(all) event TokensDeposited(amount: UFix64, to: Address?)
    access(all) event TokensMinted(amount: UFix64, type: String)
    access(all) event TokensBurned(amount: UFix64, type: String)
    
    access(all) view fun getContractViews(resourceType: Type?): [Type] {
        return [
            Type<FungibleTokenMetadataViews.FTView>(),
            Type<FungibleTokenMetadataViews.FTDisplay>(),
            Type<FungibleTokenMetadataViews.FTVaultData>(),
            Type<FungibleTokenMetadataViews.TotalSupply>()
        ]
    }
    
    access(all) fun resolveContractView(resourceType: Type?, viewType: Type): AnyStruct? {
        switch viewType {
            case Type<FungibleTokenMetadataViews.FTView>():
                return FungibleTokenMetadataViews.FTView(
                    ftDisplay: self.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTDisplay>()) as! FungibleTokenMetadataViews.FTDisplay?,
                    ftVaultData: self.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
                )
            case Type<FungibleTokenMetadataViews.FTDisplay>():
                let media = MetadataViews.Media(
                    file: MetadataViews.HTTPFile(
                        url: "https://cryptologos.cc/logos/usd-coin-usdc-logo.png"
                    ),
                    mediaType: "image/png"
                )
                let medias = MetadataViews.Medias([media])
                return FungibleTokenMetadataViews.FTDisplay(
                    name: "Wrapped USDC",
                    symbol: "WUSDC",
                    description: "Wrapped USD Coin stablecoin on Flow blockchain",
                    externalURL: MetadataViews.ExternalURL("https://www.centre.io/usdc"),
                    logos: medias,
                    socials: {
                        "twitter": MetadataViews.ExternalURL("https://twitter.com/circle")
                    }
                )
            case Type<FungibleTokenMetadataViews.FTVaultData>():
                return FungibleTokenMetadataViews.FTVaultData(
                    storagePath: self.VaultStoragePath,
                    receiverPath: self.VaultPublicPath,
                    metadataPath: self.VaultPublicPath,
                    receiverLinkedType: Type<&WrappedUSDC1.Vault>(),
                    metadataLinkedType: Type<&WrappedUSDC1.Vault>(),
                    createEmptyVaultFunction: (fun(): @{FungibleToken.Vault} {
                        return <-WrappedUSDC1.createEmptyVault(vaultType: Type<@WrappedUSDC1.Vault>())
                    })
                )
            case Type<FungibleTokenMetadataViews.TotalSupply>():
                return FungibleTokenMetadataViews.TotalSupply(
                    totalSupply: WrappedUSDC1.totalSupply
                )
        }
        return nil
    }
    
    // Vault implementation
    access(all) resource Vault: FungibleToken.Vault {
        access(all) var balance: UFix64
        
        access(FungibleToken.Withdraw) fun withdraw(amount: UFix64): @WrappedUSDC1.Vault {
            self.balance = self.balance - amount
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            return <-create Vault(balance: amount)
        }
        
        access(all) fun deposit(from: @{FungibleToken.Vault}) {
            let vault <- from as! @WrappedUSDC1.Vault
            self.balance = self.balance + vault.balance
            emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
            destroy vault
        }
        
        access(all) view fun getSupportedVaultTypes(): {Type: Bool} {
            let supportedTypes: {Type: Bool} = {}
            supportedTypes[self.getType()] = true
            return supportedTypes
        }
        
        access(all) view fun isSupportedVaultType(type: Type): Bool {
            return self.getSupportedVaultTypes()[type] ?? false
        }
        
        access(all) view fun isAvailableToWithdraw(amount: UFix64): Bool {
            return amount <= self.balance
        }
        
        access(all) fun createEmptyVault(): @WrappedUSDC1.Vault {
            return <-create Vault(balance: 0.0)
        }
        
        access(all) view fun getViews(): [Type] {
            return WrappedUSDC1.getContractViews(resourceType: nil)
        }
        
        access(all) fun resolveView(_ view: Type): AnyStruct? {
            return WrappedUSDC1.resolveContractView(resourceType: nil, viewType: view)
        }
        
        access(contract) fun burnCallback() {
            if self.balance > 0.0 {
                WrappedUSDC1.totalSupply = WrappedUSDC1.totalSupply - self.balance
            }
            self.balance = 0.0
        }
        
        init(balance: UFix64) {
            self.balance = balance
        }
    }
    
    // Minter resource
    access(all) resource Minter {
        access(all) fun mintTokens(amount: UFix64): @WrappedUSDC1.Vault {
            pre {
                amount > 0.0: "Amount must be positive"
            }
            WrappedUSDC1.totalSupply = WrappedUSDC1.totalSupply + amount
            let vault <- create Vault(balance: amount)
            emit TokensMinted(amount: amount, type: vault.getType().identifier)
            return <-vault
        }
    }
    
    // Burner resource
    access(all) resource Burner {
        access(all) fun burnTokens(from: @{FungibleToken.Vault}) {
            let vault <- from as! @WrappedUSDC1.Vault
            let amount = vault.balance
            emit TokensBurned(amount: amount, type: vault.getType().identifier)
            destroy vault
        }
    }
    
    // Public functions
    access(all) fun createEmptyVault(vaultType: Type): @WrappedUSDC1.Vault {
        return <-create Vault(balance: 0.0)
    }
    
    init() {
        self.totalSupply = 0.0
        
        self.VaultStoragePath = /storage/WrappedUSDC1Vault
        self.VaultPublicPath = /public/WrappedUSDC1Vault
        self.ReceiverPublicPath = /public/WrappedUSDC1Receiver
        self.MinterStoragePath = /storage/WrappedUSDC1Minter
        self.BurnerStoragePath = /storage/WrappedUSDC1Burner
        
        // Create minter and burner for protocol use
        let minter <- create Minter()
        let burner <- create Burner()
        
        self.account.storage.save(<-minter, to: self.MinterStoragePath)
        self.account.storage.save(<-burner, to: self.BurnerStoragePath)
        
        emit TokensInitialized(initialSupply: self.totalSupply)
    }
}