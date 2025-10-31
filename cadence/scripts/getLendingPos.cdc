import TimeLendingProtocol2 from 0x904a8cd375b62ddc

access(all) fun main(positionId: UInt64): LendingPositionInfo? {
    if let position = TimeLendingProtocol2.getLendingPosition(id: positionId) {
        return LendingPositionInfo(
            id: position.id,
            lender: position.lender,
            tokenType: position.tokenType.identifier,
            amount: position.amount,
            timestamp: position.timestamp,
            isActive: position.isActive
        )
    }
    return nil
}

access(all) struct LendingPositionInfo {
    access(all) let id: UInt64
    access(all) let lender: Address
    access(all) let tokenType: String
    access(all) let amount: UFix64
    access(all) let timestamp: UFix64
    access(all) let isActive: Bool
    
    init(id: UInt64, lender: Address, tokenType: String, amount: UFix64, timestamp: UFix64, isActive: Bool) {
        self.id = id
        self.lender = lender
        self.tokenType = tokenType
        self.amount = amount
        self.timestamp = timestamp
        self.isActive = isActive
    }
}