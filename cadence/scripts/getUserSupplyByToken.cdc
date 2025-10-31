import TimeLendingProtocol2 from 0xe11cab85e85ae137

access(all) fun main(user: Address): {String: AnyStruct} {
    var totals: {String: UFix64} = {}

    var lendingPositionId: UInt64 = 1
    while lendingPositionId < TimeLendingProtocol2.nextLendingPositionId {
        if let position = TimeLendingProtocol2.getLendingPosition(id: lendingPositionId) {
            if position.isActive && position.lender == user {
                let symbol = TimeLendingProtocol2.getTokenSymbol(tokenType: position.tokenType)
                let current = totals[symbol] ?? 0.0
                totals[symbol] = current + position.amount
            }
        }
        lendingPositionId = lendingPositionId + 1
    }

    let eth = totals["ETH"] ?? 0.0
    let usdc = totals["USDC"] ?? 0.0
    let flow = totals["FLOW"] ?? 0.0

    return {
        "ETH": eth,
        "USDC": usdc,
        "FLOW": flow,
        "breakdown": totals
    }
}


