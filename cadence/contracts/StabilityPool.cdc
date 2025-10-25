import FungibleToken from 0x9a0766d93b6608b7
import FlowToken from 0x7e60df042a9c0868
import WrappedETH1 from 0xa6729879755d30b1
import Oracle from 0xa6729879755d30b1
import TimeLendingProtocol2 from 0xa6729879755d30b1

access(all) contract LiquidationPool {
    
    // Events
    access(all) event ETHContributionAdded(contributor: Address, amount: UFix64, sharesMinted: UFix64)
    access(all) event FlowContributionAdded(contributor: Address, amount: UFix64, sharesMinted: UFix64)
    access(all) event ContributionWithdrawn(contributor: Address, sharesRedeemed: UFix64, ethAmount: UFix64, flowAmount: UFix64)
    access(all) event LiquidationExecuted(positionId: UInt64, liquidationType: String, liquidator: Address, collateralReceived: UFix64, debtRepaid: UFix64, profitGenerated: UFix64)
    access(all) event RewardsDistributed(totalETHRewards: UFix64, totalFlowRewards: UFix64, totalShares: UFix64)
    
    // Storage paths
    access(all) let PoolAdminStoragePath: StoragePath
    access(all) let PoolStoragePath: StoragePath
    access(all) let ContributorStoragePath: StoragePath
    access(all) let ContributorPublicPath: PublicPath
    
    // Pool state
    access(all) var totalShares: UFix64
    access(all) var totalETHLiquidity: UFix64
    access(all) var totalFlowLiquidity: UFix64
    access(all) var accumulatedETHRewards: UFix64
    access(all) var accumulatedFlowRewards: UFix64
    
    // Contributor tracking
    access(all) struct ContributorInfo {
        access(all) let address: Address
        access(all) var shares: UFix64
        access(all) var totalETHDeposited: UFix64
        access(all) var totalFlowDeposited: UFix64
        access(all) var ethRewardsEarned: UFix64
        access(all) var flowRewardsEarned: UFix64
        access(all) let joinedAt: UFix64
        
        init(address: Address, shares: UFix64, ethDeposited: UFix64, flowDeposited: UFix64) {
            self.address = address
            self.shares = shares
            self.totalETHDeposited = ethDeposited
            self.totalFlowDeposited = flowDeposited
            self.ethRewardsEarned = 0.0
            self.flowRewardsEarned = 0.0
            self.joinedAt = getCurrentBlock().timestamp
        }
        
        access(all) fun addShares(amount: UFix64, ethAmount: UFix64, flowAmount: UFix64) {
            self.shares = self.shares + amount
            self.totalETHDeposited = self.totalETHDeposited + ethAmount
            self.totalFlowDeposited = self.totalFlowDeposited + flowAmount
        }
        
        access(all) fun removeShares(amount: UFix64) {
            self.shares = self.shares - amount
        }
        
        access(all) fun addRewards(ethAmount: UFix64, flowAmount: UFix64) {
            self.ethRewardsEarned = self.ethRewardsEarned + ethAmount
            self.flowRewardsEarned = self.flowRewardsEarned + flowAmount
        }
    }
    
    access(all) var contributors: {Address: ContributorInfo}
    
    // Pool vaults
    access(self) var flowVault: @FlowToken.Vault
    access(self) var ethVault: @WrappedETH1.Vault
    
    // Contributor resource
    access(all) resource Contributor {
        access(all) let address: Address
        
        init(address: Address) {
            self.address = address
        }
        
        // Get contributor's share percentage
        access(all) fun getSharePercentage(): UFix64 {
            if LiquidationPool.totalShares == 0.0 {
                return 0.0
            }
            let info = LiquidationPool.contributors[self.address]!
            return (info.shares / LiquidationPool.totalShares) * 100.0
        }
        
        // Get claimable rewards
        access(all) fun getClaimableRewards(): {String: UFix64} {
            if LiquidationPool.totalShares == 0.0 {
                return {"eth": 0.0, "flow": 0.0}
            }
            let info = LiquidationPool.contributors[self.address]!
            let shareRatio = info.shares / LiquidationPool.totalShares
            return {
                "eth": shareRatio * LiquidationPool.accumulatedETHRewards,
                "flow": shareRatio * LiquidationPool.accumulatedFlowRewards
            }
        }
    }
    
    // Pool Admin resource
    access(all) resource PoolAdmin {
        
        // Contribute ETH to pool
        access(all) fun contributeETH(
            ethVault: @WrappedETH1.Vault,
            contributor: Address,
            oraclePayment: @{FungibleToken.Vault}
        ): UFix64 {
            pre {
                ethVault.balance > 0.0: "ETH deposit must be greater than 0"
            }
            
            let ethAmount = ethVault.balance
            
            // Get current ETH price from Oracle to calculate USD value for shares
            let ethPriceStr = Oracle.getPrice(symbol: "ETH", payment: <-oraclePayment)
            let ethPrice = UFix64.fromString(ethPriceStr) ?? panic("Invalid ETH price from oracle")
            
            // Calculate USD value of deposit
            let usdValue = ethAmount * ethPrice
            
            // Store ETH in pool
            LiquidationPool.ethVault.deposit(from: <-ethVault)
            LiquidationPool.totalETHLiquidity = LiquidationPool.totalETHLiquidity + ethAmount
            
            // Calculate shares to mint based on USD value
            let sharesToMint = if LiquidationPool.totalShares == 0.0 {
                usdValue  // First contributor gets 1:1 shares
            } else {
                // Total pool value in USD = ETH liquidity * ETH price + Flow liquidity
                let totalPoolValueUSD = (LiquidationPool.totalETHLiquidity * ethPrice) + LiquidationPool.totalFlowLiquidity
                // shares = (usd_value * total_shares) / total_pool_value
                (usdValue * LiquidationPool.totalShares) / totalPoolValueUSD
            }
            
            // Update contributor info
            if LiquidationPool.contributors[contributor] == nil {
                LiquidationPool.contributors[contributor] = ContributorInfo(
                    address: contributor,
                    shares: sharesToMint,
                    ethDeposited: ethAmount,
                    flowDeposited: 0.0
                )
            } else {
                LiquidationPool.contributors[contributor]!.addShares(
                    amount: sharesToMint,
                    ethAmount: ethAmount,
                    flowAmount: 0.0
                )
            }
            
            // Update pool state
            LiquidationPool.totalShares = LiquidationPool.totalShares + sharesToMint
            
            emit ETHContributionAdded(
                contributor: contributor,
                amount: ethAmount,
                sharesMinted: sharesToMint
            )
            
            return sharesToMint
        }
        
        // Contribute Flow to pool
        access(all) fun contributeFlow(
            flowVault: @FlowToken.Vault,
            contributor: Address,
            oraclePayment: @{FungibleToken.Vault}
        ): UFix64 {
            pre {
                flowVault.balance > 0.0: "Flow deposit must be greater than 0"
            }
            
            let flowAmount = flowVault.balance
            
            // Get current ETH price for calculating total pool value
            let ethPriceStr = Oracle.getPrice(symbol: "ETH", payment: <-oraclePayment)
            let ethPrice = UFix64.fromString(ethPriceStr) ?? panic("Invalid ETH price from oracle")
            
            // Flow is assumed 1:1 with USD for valuation
            let usdValue = flowAmount
            
            // Store Flow in pool
            LiquidationPool.flowVault.deposit(from: <-flowVault)
            LiquidationPool.totalFlowLiquidity = LiquidationPool.totalFlowLiquidity + flowAmount
            
            // Calculate shares to mint based on USD value
            let sharesToMint = if LiquidationPool.totalShares == 0.0 {
                usdValue  // First contributor gets 1:1 shares
            } else {
                // Total pool value in USD = ETH liquidity * ETH price + Flow liquidity
                let totalPoolValueUSD = (LiquidationPool.totalETHLiquidity * ethPrice) + LiquidationPool.totalFlowLiquidity
                // shares = (usd_value * total_shares) / total_pool_value
                (usdValue * LiquidationPool.totalShares) / totalPoolValueUSD
            }
            
            // Update contributor info
            if LiquidationPool.contributors[contributor] == nil {
                LiquidationPool.contributors[contributor] = ContributorInfo(
                    address: contributor,
                    shares: sharesToMint,
                    ethDeposited: 0.0,
                    flowDeposited: flowAmount
                )
            } else {
                LiquidationPool.contributors[contributor]!.addShares(
                    amount: sharesToMint,
                    ethAmount: 0.0,
                    flowAmount: flowAmount
                )
            }
            
            // Update pool state
            LiquidationPool.totalShares = LiquidationPool.totalShares + sharesToMint
            
            emit FlowContributionAdded(
                contributor: contributor,
                amount: flowAmount,
                sharesMinted: sharesToMint
            )
            
            return sharesToMint
        }
        
        // Withdraw contribution (get back proportional ETH and Flow)
        access(all) fun withdrawFromPool(
            shares: UFix64,
            contributor: Address,
            ethRecipient: &{FungibleToken.Receiver},
            flowRecipient: &{FungibleToken.Receiver}
        ) {
            pre {
                LiquidationPool.contributors[contributor] != nil: "Contributor not found"
                LiquidationPool.contributors[contributor]!.shares >= shares: "Insufficient shares"
                shares > 0.0: "Shares must be greater than 0"
            }
            
            // Calculate proportional amounts to return
            let shareRatio = shares / LiquidationPool.totalShares
            let ethAmount = shareRatio * LiquidationPool.totalETHLiquidity
            let flowAmount = shareRatio * LiquidationPool.totalFlowLiquidity
            
            // Ensure we have enough liquidity
            if ethAmount > LiquidationPool.ethVault.balance {
                panic("Insufficient ETH in pool. Available: ".concat(LiquidationPool.ethVault.balance.toString()))
            }
            if flowAmount > LiquidationPool.flowVault.balance {
                panic("Insufficient Flow in pool. Available: ".concat(LiquidationPool.flowVault.balance.toString()))
            }
            
            // Withdraw and send tokens
            if ethAmount > 0.0 {
                let ethToReturn <- LiquidationPool.ethVault.withdraw(amount: ethAmount)
                ethRecipient.deposit(from: <-ethToReturn)
            }
            
            if flowAmount > 0.0 {
                let flowToReturn <- LiquidationPool.flowVault.withdraw(amount: flowAmount)
                flowRecipient.deposit(from: <-flowToReturn)
            }
            
            // Update contributor info
            LiquidationPool.contributors[contributor]!.removeShares(amount: shares)
            
            // Update pool state
            LiquidationPool.totalShares = LiquidationPool.totalShares - shares
            LiquidationPool.totalETHLiquidity = LiquidationPool.totalETHLiquidity - ethAmount
            LiquidationPool.totalFlowLiquidity = LiquidationPool.totalFlowLiquidity - flowAmount
            
            emit ContributionWithdrawn(
                contributor: contributor,
                sharesRedeemed: shares,
                ethAmount: ethAmount,
                flowAmount: flowAmount
            )
        }
        
        // Execute soft liquidation using pool funds
        access(all) fun executeSoftLiquidation(
            positionId: UInt64,
            liquidatorAddress: Address,
            collateralRecipient: &{FungibleToken.Receiver},
            oraclePayment: @{FungibleToken.Vault}
        ) {
            // Update cached prices in the protocol
            TimeLendingProtocol2.updateCachedPrice(symbol: "ETH", payment: <-oraclePayment)
            
            // Get position info
            let position = TimeLendingProtocol2.getBorrowingPosition(id: positionId)
                ?? panic("Position not found")
            
            if !position.isActive {
                panic("Position is not active")
            }
            
            if position.healthFactor >= 1.0 {
                panic("Position is healthy, cannot liquidate")
            }
            
            // Calculate required repayment (assuming borrowed token is Flow/USD)
            let ethPrice = TimeLendingProtocol2.getCachedPrice(symbol: "ETH") ?? 2000.0
            let collateralValueUSD = position.collateralAmount * ethPrice
            let targetHealthFactor: UFix64 = 1.1
            let targetDebtUSD = (collateralValueUSD * position.liquidationThreshold) / targetHealthFactor
            let currentDebtUSD = position.borrowAmount * 1.0
            let debtToRepay = currentDebtUSD - targetDebtUSD
            
            // Check if pool has enough Flow liquidity
            if debtToRepay > LiquidationPool.totalFlowLiquidity {
                panic("Insufficient Flow liquidity in pool for liquidation. Required: ".concat(debtToRepay.toString()).concat(", Available: ").concat(LiquidationPool.totalFlowLiquidity.toString()))
            }
            
            // Create repayment vault from pool
            let repaymentVault <- LiquidationPool.flowVault.withdraw(amount: debtToRepay)
            
            // Execute soft liquidation
            TimeLendingProtocol2.softLiquidatePosition(
                positionId: positionId,
                liquidator: liquidatorAddress,
                repaymentVault: <-repaymentVault,
                liquidatorRecipient: collateralRecipient
            )
            
            // Calculate profit (collateral received in ETH)
            let discount = 1.0 - (position.calculatedLTV / position.liquidationThreshold)
            let liquidationBonus = 1.0 + discount
            let collateralValueLiquidated = debtToRepay * liquidationBonus
            let collateralReceivedETH = collateralValueLiquidated / ethPrice
            
            // Profit = collateral value - debt repaid
            let profitInUSD = collateralValueLiquidated - debtToRepay
            
            // Collateral goes to recipient (could be stored for rewards)
            // Here we track it as ETH rewards for the pool
            LiquidationPool.accumulatedETHRewards = LiquidationPool.accumulatedETHRewards + collateralReceivedETH
            
            // Update pool state
            LiquidationPool.totalFlowLiquidity = LiquidationPool.totalFlowLiquidity - debtToRepay
            
            emit LiquidationExecuted(
                positionId: positionId,
                liquidationType: "SoftLiquidation",
                liquidator: liquidatorAddress,
                collateralReceived: collateralReceivedETH,
                debtRepaid: debtToRepay,
                profitGenerated: profitInUSD
            )
        }
        
        // Execute hard liquidation for overdue positions
        access(all) fun executeHardLiquidation(
            positionId: UInt64,
            liquidatorAddress: Address,
            collateralRecipient: &{FungibleToken.Receiver},
            oraclePayment: @{FungibleToken.Vault}
        ) {
            // Update cached prices
            TimeLendingProtocol2.updateCachedPrice(symbol: "ETH", payment: <-oraclePayment)
            
            // Get position info
            let position = TimeLendingProtocol2.getBorrowingPosition(id: positionId)
                ?? panic("Position not found")
            
            if !position.isActive {
                panic("Position is not active")
            }
            
            if !position.isOverdue() {
                panic("Position is not overdue")
            }
            
            // Calculate total debt with interest
            let timeElapsed = getCurrentBlock().timestamp - position.timestamp
            let baseInterestRate = 0.05  // 5% annual
            let interest = position.borrowAmount * baseInterestRate * timeElapsed / 31536000.0
            let totalDebt = position.borrowAmount + interest
            
            // Check if pool has enough Flow liquidity
            if totalDebt > LiquidationPool.totalFlowLiquidity {
                panic("Insufficient Flow liquidity in pool for hard liquidation. Required: ".concat(totalDebt.toString()).concat(", Available: ").concat(LiquidationPool.totalFlowLiquidity.toString()))
            }
            
            // Create repayment vault from pool
            let repaymentVault <- LiquidationPool.flowVault.withdraw(amount: totalDebt)
            
            // Execute hard liquidation
            TimeLendingProtocol2.hardLiquidateOverduePosition(
                positionId: positionId,
                liquidator: liquidatorAddress,
                repaymentVault: <-repaymentVault,
                liquidatorRecipient: collateralRecipient
            )
            
            // Calculate profit (all collateral received - debt repaid)
            let ethPrice = TimeLendingProtocol2.getCachedPrice(symbol: "ETH") ?? 2000.0
            let collateralValueUSD = position.collateralAmount * ethPrice
            let profitInUSD = collateralValueUSD - totalDebt
            
            // Track collateral as ETH rewards
            LiquidationPool.accumulatedETHRewards = LiquidationPool.accumulatedETHRewards + position.collateralAmount
            
            // Update pool state
            LiquidationPool.totalFlowLiquidity = LiquidationPool.totalFlowLiquidity - totalDebt
            
            emit LiquidationExecuted(
                positionId: positionId,
                liquidationType: "HardLiquidation",
                liquidator: liquidatorAddress,
                collateralReceived: position.collateralAmount,
                debtRepaid: totalDebt,
                profitGenerated: profitInUSD
            )
        }
        
        // Distribute accumulated rewards to contributors
        access(all) fun distributeRewards() {
            if LiquidationPool.accumulatedETHRewards == 0.0 && LiquidationPool.accumulatedFlowRewards == 0.0 {
                return
            }
            
            let ethRewardsToDistribute = LiquidationPool.accumulatedETHRewards
            let flowRewardsToDistribute = LiquidationPool.accumulatedFlowRewards
            
            // Add rewards proportionally to each contributor's info
            for address in LiquidationPool.contributors.keys {
                let info = LiquidationPool.contributors[address]!
                let shareRatio = info.shares / LiquidationPool.totalShares
                let contributorETHReward = shareRatio * ethRewardsToDistribute
                let contributorFlowReward = shareRatio * flowRewardsToDistribute
                LiquidationPool.contributors[address]!.addRewards(ethAmount: contributorETHReward, flowAmount: contributorFlowReward)
            }
            
            // Add rewards to total liquidity
            LiquidationPool.totalETHLiquidity = LiquidationPool.totalETHLiquidity + ethRewardsToDistribute
            LiquidationPool.totalFlowLiquidity = LiquidationPool.totalFlowLiquidity + flowRewardsToDistribute
            
            emit RewardsDistributed(
                totalETHRewards: ethRewardsToDistribute, 
                totalFlowRewards: flowRewardsToDistribute,
                totalShares: LiquidationPool.totalShares
            )
            
            // Reset accumulated rewards
            LiquidationPool.accumulatedETHRewards = 0.0
            LiquidationPool.accumulatedFlowRewards = 0.0
        }
        
        // Deposit collected ETH collateral from liquidations back to pool
        access(all) fun depositETHCollateral(ethVault: @WrappedETH1.Vault) {
            let amount = ethVault.balance
            LiquidationPool.ethVault.deposit(from: <-ethVault)
            LiquidationPool.totalETHLiquidity = LiquidationPool.totalETHLiquidity + amount
        }
    }
    
    // Public functions
    access(all) fun createContributor(): @Contributor {
        return <- create Contributor(address: self.account.address)
    }
    
    access(all) fun getPoolStats(): {String: UFix64} {
        return {
            "totalShares": self.totalShares,
            "totalETHLiquidity": self.totalETHLiquidity,
            "totalFlowLiquidity": self.totalFlowLiquidity,
            "accumulatedETHRewards": self.accumulatedETHRewards,
            "accumulatedFlowRewards": self.accumulatedFlowRewards,
            "contributorCount": UFix64(self.contributors.length)
        }
    }
    
    access(all) fun getContributorInfo(address: Address): ContributorInfo? {
        return self.contributors[address]
    }
    
    access(all) fun getAllContributors(): [Address] {
        return self.contributors.keys
    }
    
    access(all) fun getLiquidatablePositions(): {String: [UInt64]} {
        return {
            "unhealthy": TimeLendingProtocol2.getUnhealthyPositions(),
            "overdue": TimeLendingProtocol2.getOverduePositions()
        }
    }
    
    init() {
        // Initialize storage paths
        self.PoolAdminStoragePath = /storage/LiquidationPoolAdmin
        self.PoolStoragePath = /storage/LiquidationPool
        self.ContributorStoragePath = /storage/LiquidationPoolContributor
        self.ContributorPublicPath = /public/LiquidationPoolContributor
        
        // Initialize pool state
        self.totalShares = 0.0
        self.totalETHLiquidity = 0.0
        self.totalFlowLiquidity = 0.0
        self.accumulatedETHRewards = 0.0
        self.accumulatedFlowRewards = 0.0
        self.contributors = {}
        
        // Create empty vaults
        self.flowVault <- FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>()) as! @FlowToken.Vault
        self.ethVault <- WrappedETH1.createEmptyVault(vaultType: Type<@WrappedETH1.Vault>())
        
        // Create and save admin
        let admin <- create PoolAdmin()
        self.account.storage.save(<-admin, to: self.PoolAdminStoragePath)
    }
}