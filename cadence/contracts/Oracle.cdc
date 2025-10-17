import BandOracle from 0x9fb6606c300b5051
import FungibleToken from 0x9a0766d93b6608b7

access(all) contract Oracle {

    access(all) event PriceUpdated(symbol: String, price: String)
    access(all) fun getPrice(symbol: String , payment: @{FungibleToken.Vault}): String {
        let price: String = BandOracle.getReferenceData(
            baseSymbol: symbol,
            quoteSymbol: "USD",
            payment: <- payment
        ).fixedPointRate.toString()
        emit PriceUpdated(symbol: symbol, price: price)
        return price
    }
}