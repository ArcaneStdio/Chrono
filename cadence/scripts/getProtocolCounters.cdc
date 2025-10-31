import TimeLendingProtocol2 from 0x904a8cd375b62ddc

access(all) fun main(): {String: UInt64} {
    return {
        "nextLendingPositionId": TimeLendingProtocol2.nextLendingPositionId,
        "nextBorrowingPositionId": TimeLendingProtocol2.nextBorrowingPositionId
    }
}








