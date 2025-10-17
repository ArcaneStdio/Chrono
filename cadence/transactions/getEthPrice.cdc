import Oracle from 0xe11cab85e85ae137
import BandOracle from 0x9fb6606c300b5051
import FungibleToken from 0x9a0766d93b6608b7
import FlowToken from 0x7e60df042a9c0868

transaction {
    let payment: @{FungibleToken.Vault}
    prepare(acct: auth(BorrowValue) &Account) {
        let vaultRef = acct.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
            from: /storage/flowTokenVault
        ) ?? panic("Cannot borrow reference to signer's FLOW vault")

        // Withdraw payment for oracle fee
        self.payment <- vaultRef.withdraw(amount: BandOracle.getFee())
    }
    execute {
        let price = Oracle.getPrice(symbol: "WBTC", payment: <- self.payment)
        log("The price of WBTC is ".concat(price).concat(" USD"))
    }
}