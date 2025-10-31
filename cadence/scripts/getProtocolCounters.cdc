import TimeLendingProtocol2 from 0xe11cab85e85ae137

access(all) fun main(): {String: UInt64} {
    return {
        "nextLendingPositionId": TimeLendingProtocol2.nextLendingPositionId,
        "nextBorrowingPositionId": TimeLendingProtocol2.nextBorrowingPositionId
    }
}







