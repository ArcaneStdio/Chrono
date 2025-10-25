import FungibleToken from 0x9a0766d93b6608b7
import MetadataViews from 0xf8d6e0586b0a20c7
import FungibleTokenMetadataViews from 0xee82856bf20e2aa6

access(all) contract WrappedETH2: FungibleToken {

    // --- Storage & Public Paths ---
    access(all) let VaultStoragePath: StoragePath
    access(all) let VaultPublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath
    access(all) let ReceiverPublicPath: PublicPath

    // --- Token State ---
    access(all) var totalSupply: UFix64

    // --- MetadataViews Support ---
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

            // Combined FT metadata view
            case Type<FungibleTokenMetadataViews.FTView>():
                return FungibleTokenMetadataViews.FTView(
                    ftDisplay: self.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTDisplay>()) as! FungibleTokenMetadataViews.FTDisplay?,
                    ftVaultData: self.resolveContractView(resourceType: nil, viewType: Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
                )

            // Display info (update these for your project)
            case Type<FungibleTokenMetadataViews.FTDisplay>():
                let media = MetadataViews.Media(
                    file: MetadataViews.HTTPFile(
                        url: "https://ethereum.org/static/4fdbf259d1a0c85b8db05c6fa0f5adf2/eth-diamond-black.png"
                    ),
                    mediaType: "image/png"
                )
                let medias = MetadataViews.Medias([media])

                return FungibleTokenMetadataViews.FTDisplay(
                    name: "Wrapped Ether",
                    symbol: "WETH",
                    description: "Wrapped version of Ether (ETH) on Flow Network.",
                    externalURL: MetadataViews.ExternalURL("https://ethereum.org/en/weth/"),
                    logos: medias,
                    socials: {
                        "twitter": MetadataViews.ExternalURL("https://twitter.com/ethereum")
                    }
                )

            // Vault data view
            case Type<FungibleTokenMetadataViews.FTVaultData>():
                return FungibleTokenMetadataViews.FTVaultData(
                    storagePath: self.VaultStoragePath,
                    receiverPath: self.VaultPublicPath,
                    metadataPath: self.VaultPublicPath,
                    receiverLinkedType: Type<&WrappedETH.Vault>(),
                    metadataLinkedType: Type<&WrappedETH.Vault>(),
                    createEmptyVaultFunction: (fun(): @{FungibleToken.Vault} {
                        return <-WrappedETH.createEmptyVault(vaultType: Type<@WrappedETH.Vault>())
                    })
                )

            // Total supply view
            case Type<FungibleTokenMetadataViews.TotalSupply>():
                return FungibleTokenMetadataViews.TotalSupply(
                    totalSupply: WrappedETH.totalSupply
                )
        }
        return nil
    }

    // --- Vault Resource ---
    access(all) resource Vault: FungibleToken.Vault {

        access(all) var balance: UFix64

        access(FungibleToken.Withdraw)
        fun withdraw(amount: UFix64): @WrappedETH.Vault {
            pre {
                self.balance >= amount: "Insufficient balance"
            }
            self.balance = self.balance - amount
            return <-create Vault(balance: amount)
        }

        access(all) fun deposit(from: @{FungibleToken.Vault}) {
            let vault <- from as! @WrappedETH.Vault
            self.balance = self.balance + vault.balance
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

        access(all) fun createEmptyVault(): @WrappedETH.Vault {
            return <-create Vault(balance: 0.0)
        }

        access(all) view fun getViews(): [Type] {
            return WrappedETH.getContractViews(resourceType: nil)
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            return WrappedETH.resolveContractView(resourceType: nil, viewType: view)
        }

        access(contract) fun burnCallback() {
            if self.balance > 0.0 {
                WrappedETH.totalSupply = WrappedETH.totalSupply - self.balance
            }
            self.balance = 0.0
        }

        init(balance: UFix64) {
            self.balance = balance
        }
    }

    // --- Minter Resource ---
    access(all) event TokensMinted(amount: UFix64, type: String)

    access(all) resource Minter {
        access(all) fun mintTokens(amount: UFix64): @WrappedETH.Vault {
            WrappedETH.totalSupply = WrappedETH.totalSupply + amount
            let vault <- create Vault(balance: amount)
            emit TokensMinted(amount: amount, type: vault.getType().identifier)
            return <-vault
        }
    }

    // --- Public Functions ---
    access(all) fun createEmptyVault(vaultType: Type): @WrappedETH.Vault {
        return <- create Vault(balance: 0.0)
    }

    // --- Initialization ---
    init() {
        self.totalSupply = 1000.0 // initial mint
        self.VaultStoragePath = /storage/wrappedETHVault
        self.VaultPublicPath = /public/wrappedETHVault
        self.MinterStoragePath = /storage/wrappedETHMinter
        self.ReceiverPublicPath = /public/wrappedETHReceiver

        // Create and store main vault
        let vault <- create Vault(balance: self.totalSupply)
        emit TokensMinted(amount: vault.balance, type: vault.getType().identifier)
        self.account.storage.save(<-vault, to: self.VaultStoragePath)

        // Publish public & receiver capabilities
        let publicCap = self.account.capabilities.storage.issue<&WrappedETH.Vault>(self.VaultStoragePath)
        self.account.capabilities.publish(publicCap, at: self.VaultPublicPath)

        let receiverCap = self.account.capabilities.storage.issue<&WrappedETH.Vault>(self.VaultStoragePath)
        self.account.capabilities.publish(receiverCap, at: self.ReceiverPublicPath)

        // Create & store minter
        let minter <- create Minter()
        self.account.storage.save(<-minter, to: self.MinterStoragePath)
    }
}
