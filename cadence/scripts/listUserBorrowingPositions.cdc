import TimeLendingProtocol2 from 0xe11cab85e85ae137

access(all) fun main(user: Address): [{String: AnyStruct}] {
    let result: [{String: AnyStruct}] = []
    var id: UInt64 = 1
    while id < TimeLendingProtocol2.nextBorrowingPositionId {
        if let p = TimeLendingProtocol2.getBorrowingPosition(id: id) {
            if p.borrower == user {
                result.append({
                    "id": p.id,
                    "collateralType": TimeLendingProtocol2.getTokenSymbol(tokenType: p.collateralType),
                    "collateralAmount": p.collateralAmount,
                    "borrowTokenType": TimeLendingProtocol2.getTokenSymbol(tokenType: p.borrowTokenType),
                    "borrowAmount": p.borrowAmount,
                    "durationMinutes": p.durationMinutes,
                    "calculatedLTV": p.calculatedLTV,
                    "liquidationThreshold": p.liquidationThreshold,
                    "healthFactor": p.healthFactor,
                    "repaymentDeadline": p.repaymentDeadline,
                    "timestamp": p.timestamp,
                    "isActive": p.isActive
                })
            }
        }
        id = id + 1
    }
    return result
}

