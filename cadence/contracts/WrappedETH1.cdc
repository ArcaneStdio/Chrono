import FungibleToken from 0x9a0766d93b6608b7
import MetadataViews from 0x631e88ae7f1d7c20
import FungibleTokenMetadataViews from 0x9a0766d93b6608b7

access(all) contract WrappedETH1: FungibleToken {
    
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
                        url: "https://ethereum.org/static/6b935ac0e6194247347855dc3d328e83/6ed5f/eth-diamond-black.webp"
                    ),
                    mediaType: "image/webp"
                )
                let medias = MetadataViews.Medias([media])
                return FungibleTokenMetadataViews.FTDisplay(
                    name: "Wrapped ETH",
                    symbol: "WETH",
                    description: "Wrapped Ethereum token on Flow blockchain",
                    externalURL: MetadataViews.ExternalURL("https://ethereum.org"),
                    logos: medias,
                    socials: {
                        "twitter": MetadataViews.ExternalURL("https://twitter.com/ethereum")
                    }
                )
            case Type<FungibleTokenMetadataViews.FTVaultData>():
                return FungibleTokenMetadataViews.FTVaultData(
                    storagePath: self.VaultStoragePath,
                    receiverPath: self.VaultPublicPath,
                    metadataPath: self.VaultPublicPath,
                    receiverLinkedType: Type<&WrappedETH1.Vault>(),
                    metadataLinkedType: Type<&WrappedETH1.Vault>(),
                    createEmptyVaultFunction: (fun(): @{FungibleToken.Vault} {
                        return <-WrappedETH1.createEmptyVault(vaultType: Type<@WrappedETH1.Vault>())
                    })
                )
            case Type<FungibleTokenMetadataViews.TotalSupply>():
                return FungibleTokenMetadataViews.TotalSupply(
                    totalSupply: WrappedETH1.totalSupply
                )
        }
        return nil
    }
    
    // Vault implementation
    access(all) resource Vault: FungibleToken.Vault {
        access(all) var balance: UFix64
        
        access(FungibleToken.Withdraw) fun withdraw(amount: UFix64): @WrappedETH1.Vault {
            self.balance = self.balance - amount
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            return <-create Vault(balance: amount)
        }
        
        access(all) fun deposit(from: @{FungibleToken.Vault}) {
            let vault <- from as! @WrappedETH1.Vault
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
        
        access(all) fun createEmptyVault(): @WrappedETH1.Vault {
            return <-create Vault(balance: 0.0)
        }
        
        access(all) view fun getViews(): [Type] {
            return WrappedETH1.getContractViews(resourceType: nil)
        }
        
        access(all) fun resolveView(_ view: Type): AnyStruct? {
            return WrappedETH1.resolveContractView(resourceType: nil, viewType: view)
        }
        
        access(contract) fun burnCallback() {
            if self.balance > 0.0 {
                WrappedETH1.totalSupply = WrappedETH1.totalSupply - self.balance
            }
            self.balance = 0.0
        }
        
        init(balance: UFix64) {
            self.balance = balance
        }
    }
    
    // Minter resource
    access(all) resource Minter {
        access(all) fun mintTokens(amount: UFix64): @WrappedETH1.Vault {
            pre {
                amount > 0.0: "Amount must be positive"
            }
            WrappedETH1.totalSupply = WrappedETH1.totalSupply + amount
            let vault <- create Vault(balance: amount)
            emit TokensMinted(amount: amount, type: vault.getType().identifier)
            return <-vault
        }
    }
    
    // Burner resource
    access(all) resource Burner {
        access(all) fun burnTokens(from: @{FungibleToken.Vault}) {
            let vault <- from as! @WrappedETH1.Vault
            let amount = vault.balance
            emit TokensBurned(amount: amount, type: vault.getType().identifier)
            destroy vault
        }
    }
    
    // Public functions
    access(all) fun createEmptyVault(vaultType: Type): @WrappedETH1.Vault {
        return <-create Vault(balance: 0.0)
    }
    
    init() {
        self.totalSupply = 0.0
        
        self.VaultStoragePath = /storage/WrappedETH1Vault
        self.VaultPublicPath = /public/WrappedETH1Vault
        self.ReceiverPublicPath = /public/WrappedETH1Receiver
        self.MinterStoragePath = /storage/WrappedETH1Minter
        self.BurnerStoragePath = /storage/WrappedETH1Burner
        
        // Create minter and burner for protocol use
        let minter <- create Minter()
        let burner <- create Burner()
        
        self.account.storage.save(<-minter, to: self.MinterStoragePath)
        self.account.storage.save(<-burner, to: self.BurnerStoragePath)
        
        emit TokensInitialized(initialSupply: self.totalSupply)
    }
}