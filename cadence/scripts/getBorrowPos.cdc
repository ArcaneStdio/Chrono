import TimeLendingProtocol2 from 0x904a8cd375b62ddc

access(all) fun main(positionId: UInt64): BorrowPositionInfo? {
    if let position = TimeLendingProtocol2.getBorrowingPosition(id: positionId) {
        return BorrowPositionInfo(
            id: position.id,
            borrower: position.borrower,
            collateralType: position.collateralType.identifier,
            collateralAmount: position.collateralAmount,
            borrowTokenType: position.borrowTokenType.identifier,
            borrowAmount: position.borrowAmount,
            durationMinutes: position.durationMinutes,
            calculatedLTV: position.calculatedLTV,
            liquidationThreshold: position.liquidationThreshold,
            healthFactor: position.healthFactor
        )
    }
    return nil
}

access(all) struct BorrowPositionInfo {
    access(all) let id: UInt64
    access(all) let borrower: Address
    access(all) let collateralType: String
    access(all) let collateralAmount: UFix64
    access(all) let borrowTokenType: String
    access(all) let borrowAmount: UFix64
    access(all) let durationMinutes: UInt64
    access(all) let calculatedLTV: UFix64
    access(all) let liquidationThreshold: UFix64
    access(all) let healthFactor: UFix64

    init(id: UInt64, borrower: Address, collateralType: String, collateralAmount: UFix64, borrowTokenType: String, borrowAmount: UFix64, durationMinutes: UInt64, calculatedLTV: UFix64, liquidationThreshold: UFix64, healthFactor: UFix64) {
        self.id = id
        self.borrower = borrower
        self.collateralType = collateralType
        self.collateralAmount = collateralAmount
        self.borrowTokenType = borrowTokenType
        self.borrowAmount = borrowAmount
        self.durationMinutes = durationMinutes
        self.calculatedLTV = calculatedLTV
        self.liquidationThreshold = liquidationThreshold
        self.healthFactor = healthFactor
    }
}