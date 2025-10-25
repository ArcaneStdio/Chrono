import FungibleToken from 0x9a0766d93b6608b7
import WrappedETH1 from 0xe11cab85e85ae137

// This transaction sets up an account to receive WrappedETH1 tokens
// using correct Cadence 1.0+ syntax with interface-based capabilities.

transaction {

    prepare(signer: auth(Storage, Capabilities) &Account) {
        let vault <- WrappedETH1.createEmptyVault(vaultType: Type<@WrappedETH1.Vault>())
        signer.storage.save(<-vault, to: WrappedETH1.VaultStoragePath)
        log("Created a new WrappedETH1 Vault.")

        // 2. Define receiver and balance public paths.
        let receiverPath = WrappedETH1.ReceiverPublicPath

        // 3. Unpublish any old or incorrect capabilities at those paths.
        if signer.capabilities.exists(receiverPath) {
            signer.capabilities.unpublish(receiverPath)
        }

        // 4. Issue new capabilities restricted to the appropriate interfaces.
        let receiverCapability = signer.capabilities.storage.issue<&{FungibleToken.Receiver}>(WrappedETH1.VaultStoragePath)

        // 5. Publish these capabilities to the correct public paths.
        signer.capabilities.publish(receiverCapability, at: receiverPath)

        log("Published WrappedETH1 Receiver capabilities using Cadence 1.0+ syntax.")
    }

    execute {
        log("WrappedETH1 Vault setup complete.")
    }
}