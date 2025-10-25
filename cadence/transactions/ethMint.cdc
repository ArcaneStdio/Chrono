import FungibleToken from 0x9a0766d93b6608b7
import WrappedETH1 from 0xe11cab85e85ae137

// This transaction mints new WrappedETH1 tokens and deposits them into a recipient's vault.
// It must be signed by the account that deployed the WrappedETH1 contract.

transaction(amount: UFix64, recipient: Address) {

    /// Reference to the Minter resource stored in the signer's account
    let minter: &WrappedETH1.Minter

    /// Reference to the recipient's FungibleToken.Receiver capability
    let recipientReceiver: &{FungibleToken.Receiver}

    prepare(signer: auth(BorrowValue) &Account) {
        
        // --- 1. Borrow Minter Reference ---
        // Borrow a reference to the Minter resource from the signer's storage.
        self.minter = signer.storage.borrow<&WrappedETH1.Minter>(from: WrappedETH1.MinterStoragePath)
            ?? panic("Could not borrow a reference to the Minter resource")

        // --- 2. Get Recipient's Receiver Reference ---
        // Get the recipient's public account object.
        let recipientAccount = getAccount(recipient)

        // Borrow a reference to the recipient's public Receiver capability.
        // This assumes the recipient has already set up a vault at the standard path.
        self.recipientReceiver = recipientAccount.capabilities.get<&{FungibleToken.Receiver}>(WrappedETH1.ReceiverPublicPath)
            .borrow()
            ?? panic("Could not borrow receiver reference from recipient's account. Make sure the recipient has set up their vault.")
    }

    execute {
        // --- 3. Mint Tokens ---
        // Mint new tokens using the Minter reference.
        let mintedVault <- self.minter.mintTokens(amount: amount)
        
        // --- 4. Deposit Tokens ---
        // Deposit the newly minted tokens into the recipient's vault.
        self.recipientReceiver.deposit(from: <-mintedVault)

        log("Successfully minted and deposited ".concat(amount.toString()).concat(" WrappedETH1 to ").concat(recipient.toString()))
    }
}