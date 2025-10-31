import TimeLendingProtocol2 from 0xe11cab85e85ae137

access(all) fun main(user: Address): {String: AnyStruct} {
    var borrowTotals: {String: UFix64} = {}
    var collateralBreakdown: {String: {String: UFix64}} = {}
    
    var positions: [{String: AnyStruct}] = []

    var borrowingPositionId: UInt64 = 1
    while borrowingPositionId < TimeLendingProtocol2.nextBorrowingPositionId {
        if let position = TimeLendingProtocol2.getBorrowingPosition(id: borrowingPositionId) {
            if position.isActive && position.borrower == user {
                let borrowSymbol = TimeLendingProtocol2.getTokenSymbol(tokenType: position.borrowTokenType)
                let collateralSymbol = TimeLendingProtocol2.getTokenSymbol(tokenType: position.collateralType)
                
                let currentBorrow = borrowTotals[borrowSymbol] ?? 0.0
                borrowTotals[borrowSymbol] = currentBorrow + position.borrowAmount
                
                if collateralBreakdown[borrowSymbol] == nil {
                    collateralBreakdown[borrowSymbol] = {}
                }
                let currentCollateral = collateralBreakdown[borrowSymbol]![collateralSymbol] ?? 0.0
                collateralBreakdown[borrowSymbol]![collateralSymbol] = currentCollateral + position.collateralAmount
                
                // Store position details
                positions.append({
                    "id": position.id,
                    "collateralType": collateralSymbol,
                    "collateralAmount": position.collateralAmount,
                    "borrowTokenType": borrowSymbol,
                    "borrowAmount": position.borrowAmount,
                    "durationMinutes": position.durationMinutes,
                    "calculatedLTV": position.calculatedLTV,
                    "healthFactor": position.healthFactor,
                    "repaymentDeadline": position.repaymentDeadline,
                    "timestamp": position.timestamp
                })
            }
        }
        borrowingPositionId = borrowingPositionId + 1
    }

    let usdc = borrowTotals["USDC"] ?? 0.0
    let eth = borrowTotals["ETH"] ?? 0.0
    let flow = borrowTotals["FLOW"] ?? 0.0

    return {
        "USDC": usdc,
        "ETH": eth,
        "FLOW": flow,
        "breakdown": borrowTotals,
        "collateralBreakdown": collateralBreakdown,
        "positions": positions
    }
}

