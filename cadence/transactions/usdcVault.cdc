import FungibleToken from 0x9a0766d93b6608b7
import WrappedUSDC1 from 0xe11cab85e85ae137

// This transaction sets up an account to receive WrappedUSDC1 tokens
// using correct Cadence 1.0+ syntax with interface-based capabilities.

transaction {

    prepare(signer: auth(Storage, Capabilities) &Account) {
        let vault <- WrappedUSDC1.createEmptyVault(vaultType: Type<@WrappedUSDC1.Vault>())
        signer.storage.save(<-vault, to: WrappedUSDC1.VaultStoragePath)
        log("Created a new WrappedUSDC1 Vault.")

        // 2. Define receiver and balance public paths.
        let receiverPath = WrappedUSDC1.ReceiverPublicPath

        // 3. Unpublish any old or incorrect capabilities at those paths.
        if signer.capabilities.exists(receiverPath) {
            signer.capabilities.unpublish(receiverPath)
        }

        // 4. Issue new capabilities restricted to the appropriate interfaces.
        let receiverCapability = signer.capabilities.storage.issue<&{FungibleToken.Receiver}>(WrappedUSDC1.VaultStoragePath)

        // 5. Publish these capabilities to the correct public paths.
        signer.capabilities.publish(receiverCapability, at: receiverPath)

        log("Published WrappedUSDC1 Receiver capabilities using Cadence 1.0+ syntax.")
    }

    execute {
        log("WrappedUSDC1 Vault setup complete.")
    }
}