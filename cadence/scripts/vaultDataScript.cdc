import FungibleToken from 0x9a0766d93b6608b7
import TimeLendingProtocol2 from 0x904a8cd375b62ddc
import WrappedETH1 from 0xe11cab85e85ae137
import WrappedUSDC1 from 0xe11cab85e85ae137
import FlowToken from 0x7e60df042a9c0868

// Script to get comprehensive information about all lending vaults
// Returns vault balances, utilization rates, and statistics

access(all) struct VaultInfo {
    access(all) let tokenType: String
    access(all) let totalDeposited: UFix64
    access(all) let totalBorrowed: UFix64
    access(all) let availableLiquidity: UFix64
    access(all) let utilizationRate: UFix64  // Percentage of vault being borrowed
    access(all) let numberOfActiveBorrowPositions: Int
    access(all) let numberOfActiveLendingPositions: Int
    access(all) let price: UFix64
    access(all) let lastPriceUpdate: UFix64
    
    init(
        tokenType: String,
        totalDeposited: UFix64,
        totalBorrowed: UFix64,
        availableLiquidity: UFix64,
        utilizationRate: UFix64,
        numberOfActiveBorrowPositions: Int,
        numberOfActiveLendingPositions: Int,
        price: UFix64,
        lastPriceUpdate: UFix64
    ) {
        self.tokenType = tokenType
        self.totalDeposited = totalDeposited
        self.totalBorrowed = totalBorrowed
        self.availableLiquidity = availableLiquidity
        self.utilizationRate = utilizationRate
        self.numberOfActiveBorrowPositions = numberOfActiveBorrowPositions
        self.numberOfActiveLendingPositions = numberOfActiveLendingPositions
        self.price = price
        self.lastPriceUpdate = lastPriceUpdate
    }
}

access(all) struct ProtocolStats {
    access(all) let totalValueLocked: UFix64  // In USD
    access(all) let totalBorrowed: UFix64     // In USD
    access(all) let vaults: [VaultInfo]
    access(all) let activeLendingPositions: Int
    access(all) let activeBorrowingPositions: Int
    access(all) let unhealthyPositions: Int
    access(all) let overduePositions: Int
    
    init(
        totalValueLocked: UFix64,
        totalBorrowed: UFix64,
        vaults: [VaultInfo],
        activeLendingPositions: Int,
        activeBorrowingPositions: Int,
        unhealthyPositions: Int,
        overduePositions: Int
    ) {
        self.totalValueLocked = totalValueLocked
        self.totalBorrowed = totalBorrowed
        self.vaults = vaults
        self.activeLendingPositions = activeLendingPositions
        self.activeBorrowingPositions = activeBorrowingPositions
        self.unhealthyPositions = unhealthyPositions
        self.overduePositions = overduePositions
    }
}

access(all) fun main(): ProtocolStats {
    // Define token types to check
    let tokenTypes: [Type] = [
        Type<@WrappedETH1.Vault>(),
        Type<@WrappedUSDC1.Vault>(),
        Type<@FlowToken.Vault>()
    ]
    
    let tokenNames: {Type: String} = {
        Type<@WrappedETH1.Vault>(): "WrappedETH",
        Type<@WrappedUSDC1.Vault>(): "WrappedUSDC",
        Type<@FlowToken.Vault>(): "FlowToken"
    }
    
    let tokenSymbols: {Type: String} = {
        Type<@WrappedETH1.Vault>(): "ETH",
        Type<@WrappedUSDC1.Vault>(): "USDC",
        Type<@FlowToken.Vault>(): "FLOW"
    }
    
    var vaultInfos: [VaultInfo] = []
    var totalTVL: UFix64 = 0.0
    var totalBorrowedUSD: UFix64 = 0.0
    
    // Calculate borrowed amounts and deposited amounts per token type
    var borrowedAmounts: {Type: UFix64} = {}
    var depositedAmounts: {Type: UFix64} = {}
    var activeBorrowCountPerToken: {Type: Int} = {}
    var activeLendingCountPerToken: {Type: Int} = {}
    
    // Initialize counters
    for tokenType in tokenTypes {
        borrowedAmounts[tokenType] = 0.0
        depositedAmounts[tokenType] = 0.0
        activeBorrowCountPerToken[tokenType] = 0
        activeLendingCountPerToken[tokenType] = 0
    }
    
    // Iterate through all borrowing positions to calculate total borrowed
    var positionId: UInt64 = 1
    var activeBorrowingPositions = 0
    
    while positionId < TimeLendingProtocol2.nextBorrowingPositionId {
        if let position = TimeLendingProtocol2.getBorrowingPosition(id: positionId) {
            if position.isActive {
                activeBorrowingPositions = activeBorrowingPositions + 1
                
                // Add to borrowed amount for this token type
                let currentBorrowed = borrowedAmounts[position.borrowTokenType] ?? 0.0
                borrowedAmounts[position.borrowTokenType] = currentBorrowed + position.borrowAmount
                
                // Increment active borrow count
                let currentCount = activeBorrowCountPerToken[position.borrowTokenType] ?? 0
                activeBorrowCountPerToken[position.borrowTokenType] = currentCount + 1
            }
        }
        positionId = positionId + 1
    }
    
    // Iterate through all lending positions to calculate total deposited
    var activeLendingPositions = 0
    var lendingPositionId: UInt64 = 1
    
    while lendingPositionId < TimeLendingProtocol2.nextLendingPositionId {
        if let position = TimeLendingProtocol2.getLendingPosition(id: lendingPositionId) {
            if position.isActive {
                activeLendingPositions = activeLendingPositions + 1
                
                // Add to deposited amount for this token type
                let currentDeposited = depositedAmounts[position.tokenType] ?? 0.0
                depositedAmounts[position.tokenType] = currentDeposited + position.amount
                
                // Increment active lending count
                let currentCount = activeLendingCountPerToken[position.tokenType] ?? 0
                activeLendingCountPerToken[position.tokenType] = currentCount + 1
            }
        }
        lendingPositionId = lendingPositionId + 1
    }
    
    // Get vault information for each token type
    for tokenType in tokenTypes {
        let tokenName = tokenNames[tokenType] ?? "Unknown"
        let symbol = tokenSymbols[tokenType] ?? "UNKNOWN"
        
        // Get deposited amount from lending positions
        let totalDeposited = depositedAmounts[tokenType] ?? 0.0
        
        // Get borrowed amount for this token
        let totalBorrowed = borrowedAmounts[tokenType] ?? 0.0
        
        // Calculate available liquidity (deposited - borrowed)
        let availableLiquidity = totalDeposited - totalBorrowed
        
        // Calculate utilization rate
        var utilizationRate: UFix64 = 0.0
        if totalDeposited > 0.0 {
            utilizationRate = (totalBorrowed / totalDeposited) * 100.0
        }
        
        // Get price from cache
        let price = TimeLendingProtocol2.getCachedPrice(symbol: symbol) ?? 1.0
        let lastUpdate = TimeLendingProtocol2.getLastPriceUpdate(symbol: symbol) ?? 0.0
        
        // Get active counts for this token
        let activeBorrowCount = activeBorrowCountPerToken[tokenType] ?? 0
        let activeLendingCount = activeLendingCountPerToken[tokenType] ?? 0
        
        // Calculate TVL contribution (in USD)
        totalTVL = totalTVL + (totalDeposited * price)
        totalBorrowedUSD = totalBorrowedUSD + (totalBorrowed * price)
        
        // Create vault info
        let vaultInfo = VaultInfo(
            tokenType: tokenName,
            totalDeposited: totalDeposited,
            totalBorrowed: totalBorrowed,
            availableLiquidity: availableLiquidity,
            utilizationRate: utilizationRate,
            numberOfActiveBorrowPositions: activeBorrowCount,
            numberOfActiveLendingPositions: activeLendingCount,
            price: price,
            lastPriceUpdate: lastUpdate
        )
        
        vaultInfos.append(vaultInfo)
    }
    
    // Get unhealthy and overdue positions
    let unhealthyPositions = TimeLendingProtocol2.getUnhealthyPositions()
    let overduePositions = TimeLendingProtocol2.getOverduePositions()
    
    // Create and return protocol stats
    return ProtocolStats(
        totalValueLocked: totalTVL,
        totalBorrowed: totalBorrowedUSD,
        vaults: vaultInfos,
        activeLendingPositions: activeLendingPositions,
        activeBorrowingPositions: activeBorrowingPositions,
        unhealthyPositions: unhealthyPositions.length,
        overduePositions: overduePositions.length
    )
}