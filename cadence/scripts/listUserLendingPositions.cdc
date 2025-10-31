import TimeLendingProtocol2 from 0x904a8cd375b62ddc

access(all) fun main(user: Address): [{String: AnyStruct}] {
    let result: [{String: AnyStruct}] = []
    var id: UInt64 = 1
    while id < TimeLendingProtocol2.nextLendingPositionId {
        if let p = TimeLendingProtocol2.getLendingPosition(id: id) {
            if p.lender == user {
                result.append({
                    "id": p.id,
                    "token": TimeLendingProtocol2.getTokenSymbol(tokenType: p.tokenType),
                    "amount": p.amount,
                    "isActive": p.isActive,
                    "timestamp": p.timestamp
                })
            }
        }
        id = id + 1
    }
    return result
}








