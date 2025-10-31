import FungibleToken from 0x9a0766d93b6608b7
import FlowToken from 0x7e60df042a9c0868
import WrappedETH1 from 0xe11cab85e85ae137
import WrappedUSDC1 from 0xe11cab85e85ae137
import Oracle from 0xa6729879755d30b1
import TimeLendingProtocol2 from 0xe11cab85e85ae137
import BandOracle from 0x9fb6606c300b5051

access(all) contract LiquidationPool {
    
    // Events
    access(all) event ETHContributionAdded(contributor: Address, amount: UFix64, sharesMinted: UFix64)
    access(all) event USDCContributionAdded(contributor: Address, amount: UFix64, sharesMinted: UFix64)
    access(all) event FlowContributionAdded(contributor: Address, amount: UFix64, sharesMinted: UFix64)
    access(all) event ContributionWithdrawn(contributor: Address, sharesRedeemed: UFix64, ethAmount: UFix64, usdcAmount: UFix64, flowAmount: UFix64)
    access(all) event LiquidationExecuted(positionId: UInt64, liquidationType: String, liquidator: Address, collateralReceived: UFix64, collateralType: String, debtRepaid: UFix64, profitGenerated: UFix64)
    access(all) event CollateralCollected(tokenType: String, amount: UFix64, usdValue: UFix64)
    access(all) event RewardsConverted(tokensSold: String, amountSold: UFix64, flowReceived: UFix64)
    access(all) event RewardsDistributed(totalFlowRewards: UFix64, totalShares: UFix64)
    access(all) event RewardsClaimed(contributor: Address, flowAmount: UFix64)
    
    // Storage paths
    access(all) let PoolAdminStoragePath: StoragePath
    access(all) let PoolStoragePath: StoragePath
    access(all) let ContributorStoragePath: StoragePath
    access(all) let ContributorPublicPath: PublicPath
    
    // Pool state
    access(all) var totalShares: UFix64
    access(all) var totalETHLiquidity: UFix64
    access(all) var totalUSDCLiquidity: UFix64
    access(all) var totalFlowLiquidity: UFix64
    
    // Pending rewards (Flow tokens waiting to be distributed)
    access(all) var pendingFlowRewards: UFix64
    
    // Contributor tracking
    access(all) struct ContributorInfo {
        access(all) let address: Address
        access(all) var shares: UFix64
        access(all) var totalETHDeposited: UFix64
        access(all) var totalUSDCDeposited: UFix64
        access(all) var totalFlowDeposited: UFix64
        access(all) var claimableFlowRewards: UFix64
        access(all) var totalFlowRewardsClaimed: UFix64
        access(all) let joinedAt: UFix64
        
        init(address: Address, shares: UFix64, ethDeposited: UFix64, usdcDeposited: UFix64, flowDeposited: UFix64) {
            self.address = address
            self.shares = shares
            self.totalETHDeposited = ethDeposited
            self.totalUSDCDeposited = usdcDeposited
            self.totalFlowDeposited = flowDeposited
            self.claimableFlowRewards = 0.0
            self.totalFlowRewardsClaimed = 0.0
            self.joinedAt = getCurrentBlock().timestamp
        }
        
        access(all) fun addShares(amount: UFix64, ethAmount: UFix64, usdcAmount: UFix64, flowAmount: UFix64) {
            self.shares = self.shares + amount
            self.totalETHDeposited = self.totalETHDeposited + ethAmount
            self.totalUSDCDeposited = self.totalUSDCDeposited + usdcAmount
            self.totalFlowDeposited = self.totalFlowDeposited + flowAmount
        }
        
        access(all) fun removeShares(amount: UFix64) {
            pre {
                self.shares >= amount: "Insufficient shares"
            }
            self.shares = self.shares - amount
        }
        
        access(all) fun addRewards(flowAmount: UFix64) {
            self.claimableFlowRewards = self.claimableFlowRewards + flowAmount
        }
        
        access(all) fun claimRewards(amount: UFix64) {
            pre {
                self.claimableFlowRewards >= amount: "Insufficient claimable rewards"
            }
            self.claimableFlowRewards = self.claimableFlowRewards - amount
            self.totalFlowRewardsClaimed = self.totalFlowRewardsClaimed + amount
        }
    }
    
    access(all) var contributors: {Address: ContributorInfo}
    
    // Pool vaults (liquidity for liquidations)
    access(self) var flowVault: @FlowToken.Vault
    access(self) var ethVault: @WrappedETH1.Vault
    access(self) var usdcVault: @WrappedUSDC1.Vault
    
    // Collateral vaults (holds liquidated collateral before conversion to Flow)
    access(self) var collateralETHVault: @WrappedETH1.Vault
    access(self) var collateralUSDCVault: @WrappedUSDC1.Vault
    
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
            let info = LiquidationPool.contributors[self.address]
                ?? panic("Contributor not found")
            return (info.shares / LiquidationPool.totalShares) * 100.0
        }
        
        // Get claimable rewards
        access(all) fun getClaimableRewards(): UFix64 {
            let info = LiquidationPool.contributors[self.address]
                ?? panic("Contributor not found")
            return info.claimableFlowRewards
        }
        
        // Claim rewards
        access(all) fun claimRewards(recipient: &{FungibleToken.Receiver}) {
            let info = LiquidationPool.contributors[self.address]
                ?? panic("Contributor not found")
            
            let claimableAmount = info.claimableFlowRewards
            if claimableAmount == 0.0 {
                panic("No rewards to claim")
            }
            
            // Withdraw from pool's flow vault
            let rewardVault <- LiquidationPool.flowVault.withdraw(amount: claimableAmount)
            recipient.deposit(from: <-rewardVault)
            
            // Update contributor info
            LiquidationPool.contributors[self.address]!.claimRewards(amount: claimableAmount)
            
            emit RewardsClaimed(contributor: self.address, flowAmount: claimableAmount)
        }
    }

    // Pool Admin resource
    access(all) resource PoolAdmin {
        
        // Helper function to get total pool value in USD
        access(all) fun getTotalPoolValueUSD(ethPrice: UFix64): UFix64 {
            // ETH value in USD + USDC (1:1 with USD) + Flow (1:1 with USD)
            return (LiquidationPool.totalETHLiquidity * ethPrice) + 
                   LiquidationPool.totalUSDCLiquidity + 
                   LiquidationPool.totalFlowLiquidity
        }
        
        // Contribute ETH to pool
        
        // Execute soft liquidation using pool funds (for positions with Flow/USDC debt)
        access(all) fun executeSoftLiquidation(
            positionId: UInt64,
            liquidatorAddress: Address,
            debtTokenType: String, // "FLOW" or "USDC"
            oraclePayment: @{FungibleToken.Vault}
        ) {
            pre {
                debtTokenType == "FLOW" || debtTokenType == "USDC": "Invalid debt token type"
            }
            
            // Update cached prices
            TimeLendingProtocol2.updateCachedPrice(symbol: "ETH", payment: <-oraclePayment)
            
            // Get position info
            let position = TimeLendingProtocol2.getBorrowingPosition(id: positionId)
                ?? panic("Position not found")
            
            assert(position.isActive, message: "Position is not active")
            assert(position.healthFactor < 1.0, message: "Position is healthy, cannot liquidate")
            
            // Calculate required repayment
            let ethPrice = TimeLendingProtocol2.getCachedPrice(symbol: "ETH") ?? 2000.0
            let collateralValueUSD = position.collateralAmount * ethPrice
            let targetHealthFactor: UFix64 = 1.1
            let targetDebtUSD = (collateralValueUSD * position.liquidationThreshold) / targetHealthFactor
            let currentDebtUSD = position.borrowAmount
            let debtToRepay = currentDebtUSD - targetDebtUSD
            
            // Create repayment vault based on debt token type
            var repaymentVault: @{FungibleToken.Vault}? <- nil
            
            if debtTokenType == "FLOW" {
                assert(debtToRepay <= LiquidationPool.totalFlowLiquidity, 
                    message: "Insufficient Flow liquidity. Required: ".concat(debtToRepay.toString()))
                repaymentVault <-! LiquidationPool.flowVault.withdraw(amount: debtToRepay)
                LiquidationPool.totalFlowLiquidity = LiquidationPool.totalFlowLiquidity - debtToRepay
            } else if debtTokenType == "USDC" {
                assert(debtToRepay <= LiquidationPool.totalUSDCLiquidity, 
                    message: "Insufficient USDC liquidity. Required: ".concat(debtToRepay.toString()))
                repaymentVault <-! LiquidationPool.usdcVault.withdraw(amount: debtToRepay)
                LiquidationPool.totalUSDCLiquidity = LiquidationPool.totalUSDCLiquidity - debtToRepay
            }
            
            // Get collateral recipient capability
            let collateralRecipient = LiquidationPool.account.capabilities.get<&{FungibleToken.Receiver}>(/public/wrappedETH1Receiver)
                .borrow() ?? panic("Could not borrow ETH receiver capability")
            
            // Execute soft liquidation
            TimeLendingProtocol2.softLiquidatePosition(
                positionId: positionId,
                liquidator: liquidatorAddress,
                repaymentVault: <-repaymentVault!,
                liquidatorRecipient: collateralRecipient
            )
            
            // Calculate collateral received
            let discount = 1.0 - (position.calculatedLTV / position.liquidationThreshold)
            let liquidationBonus = 1.0 + discount
            let collateralValueLiquidated = debtToRepay * liquidationBonus
            let collateralReceivedETH = collateralValueLiquidated / ethPrice
            let profitInUSD = collateralValueLiquidated - debtToRepay
            
            emit LiquidationExecuted(
                positionId: positionId,
                liquidationType: "SoftLiquidation",
                liquidator: liquidatorAddress,
                collateralReceived: collateralReceivedETH,
                collateralType: "ETH",
                debtRepaid: debtToRepay,
                profitGenerated: profitInUSD
            )
            
            emit CollateralCollected(
                tokenType: "ETH",
                amount: collateralReceivedETH,
                usdValue: collateralValueLiquidated
            )
        }
        
        // Execute hard liquidation for overdue position
        
        // Convert collected ETH collateral to Flow rewards
        access(all) fun depositFlowRewardsFromETH(flowVault: @FlowToken.Vault, ethSold: UFix64) {
            let flowAmount = flowVault.balance
            LiquidationPool.flowVault.deposit(from: <-flowVault)
            LiquidationPool.pendingFlowRewards = LiquidationPool.pendingFlowRewards + flowAmount
            
            emit RewardsConverted(tokensSold: "ETH", amountSold: ethSold, flowReceived: flowAmount)
        }
        
        // Convert collected USDC collateral to Flow rewards
        access(all) fun depositFlowRewardsFromUSDC(flowVault: @FlowToken.Vault, usdcSold: UFix64) {
            let flowAmount = flowVault.balance
            LiquidationPool.flowVault.deposit(from: <-flowVault)
            LiquidationPool.pendingFlowRewards = LiquidationPool.pendingFlowRewards + flowAmount
            
            emit RewardsConverted(tokensSold: "USDC", amountSold: usdcSold, flowReceived: flowAmount)
        }
        
        // Distribute pending Flow rewards to contributors
        access(all) fun distributeRewards() {
            pre {
                LiquidationPool.pendingFlowRewards > 0.0: "No rewards to distribute"
                LiquidationPool.totalShares > 0.0: "No contributors in pool"
            }
            
            let rewardsToDistribute = LiquidationPool.pendingFlowRewards
            
            // Add rewards proportionally to each contributor's claimable amount
            for address in LiquidationPool.contributors.keys {
                let info = LiquidationPool.contributors[address]!
                let shareRatio = info.shares / LiquidationPool.totalShares
                let contributorFlowReward = shareRatio * rewardsToDistribute
                LiquidationPool.contributors[address]!.addRewards(flowAmount: contributorFlowReward)
            }
            
            emit RewardsDistributed(
                totalFlowRewards: rewardsToDistribute,
                totalShares: LiquidationPool.totalShares
            )
            
            // Reset pending rewards
            LiquidationPool.pendingFlowRewards = 0.0
        }
        
        // Withdraw collected ETH collateral (for manual sale/swap)
        access(all) fun withdrawCollateralETH(amount: UFix64, recipient: &{FungibleToken.Receiver}) {
            pre {
                amount <= LiquidationPool.collateralETHVault.balance: "Insufficient collateral ETH"
            }
            let ethVault <- LiquidationPool.collateralETHVault.withdraw(amount: amount)
            recipient.deposit(from: <-ethVault)
        }
        
        // Withdraw collected USDC collateral (for manual sale/swap)
        access(all) fun withdrawCollateralUSDC(amount: UFix64, recipient: &{FungibleToken.Receiver}) {
            pre {
                amount <= LiquidationPool.collateralUSDCVault.balance: "Insufficient collateral USDC"
            }
            let usdcVault <- LiquidationPool.collateralUSDCVault.withdraw(amount: amount)
            recipient.deposit(from: <-usdcVault)
        }
        
        // Emergency function to move ETH collateral to main pool
        access(all) fun moveETHCollateralToPool() {
            let amount = LiquidationPool.collateralETHVault.balance
            if amount > 0.0 {
                let vault <- LiquidationPool.collateralETHVault.withdraw(amount: amount)
                LiquidationPool.ethVault.deposit(from: <-vault)
                LiquidationPool.totalETHLiquidity = LiquidationPool.totalETHLiquidity + amount
            }
        }
        
        // Emergency function to move USDC collateral to main pool
        access(all) fun moveUSDCCollateralToPool() {
            let amount = LiquidationPool.collateralUSDCVault.balance
            if amount > 0.0 {
                let vault <- LiquidationPool.collateralUSDCVault.withdraw(amount: amount)
                LiquidationPool.usdcVault.deposit(from: <-vault)
                LiquidationPool.totalUSDCLiquidity = LiquidationPool.totalUSDCLiquidity + amount
            }
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
            "totalUSDCLiquidity": self.totalUSDCLiquidity,
            "totalFlowLiquidity": self.totalFlowLiquidity,
            "pendingFlowRewards": self.pendingFlowRewards,
            "collateralETHBalance": self.collateralETHVault.balance,
            "collateralUSDCBalance": self.collateralUSDCVault.balance,
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

    access(all) fun contributeETH(
            ethVault: @WrappedETH1.Vault,
            contributor: Address,
            oraclePayment: @{FungibleToken.Vault}
        ): UFix64 {
            pre {
                ethVault.balance > 0.0: "ETH deposit must be greater than 0"
            }
            
            let ethAmount = ethVault.balance
            
            // Get current ETH price from Oracle
            let ethPriceStr = Oracle.getPrice(symbol: "ETH", payment: <-oraclePayment)
            let ethPrice = UFix64.fromString(ethPriceStr) ?? panic("Invalid ETH price from oracle")
            
            // Calculate USD value of deposit
            let usdValue = ethAmount * ethPrice
            
            // Store ETH in pool
            LiquidationPool.ethVault.deposit(from: <-ethVault)
            LiquidationPool.totalETHLiquidity = LiquidationPool.totalETHLiquidity + ethAmount

            var sharesToMint : UFix64 = 0.0

            if LiquidationPool.totalShares == 0.0 {
                sharesToMint = usdValue
            } else {
                let totalPoolValueUSD = self.getTotalPoolValueUSD(ethPrice: ethPrice)
                sharesToMint = (usdValue * LiquidationPool.totalShares) / totalPoolValueUSD
            }
            
            // Update contributor info
            if LiquidationPool.contributors[contributor] == nil {
                LiquidationPool.contributors[contributor] = ContributorInfo(
                    address: contributor,
                    shares: sharesToMint,
                    ethDeposited: ethAmount,
                    usdcDeposited: 0.0,
                    flowDeposited: 0.0
                )
            } else {
                LiquidationPool.contributors[contributor]!.addShares(
                    amount: sharesToMint,
                    ethAmount: ethAmount,
                    usdcAmount: 0.0,
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
        
        // Contribute USDC to pool
        access(all) fun contributeUSDC(
            usdcVault: @WrappedUSDC1.Vault,
            contributor: Address,
            oraclePayment: @{FungibleToken.Vault}
        ): UFix64 {
            pre {
                usdcVault.balance > 0.0: "USDC deposit must be greater than 0"
            }
            
            let usdcAmount = usdcVault.balance
            
            // Get ETH price for calculating total pool value
            let ethPriceStr = Oracle.getPrice(symbol: "ETH", payment: <-oraclePayment)
            let ethPrice = UFix64.fromString(ethPriceStr) ?? panic("Invalid ETH price from oracle")
            
            // USDC is 1:1 with USD
            let usdValue = usdcAmount
            
            // Store USDC in pool
            LiquidationPool.usdcVault.deposit(from: <-usdcVault)
            LiquidationPool.totalUSDCLiquidity = LiquidationPool.totalUSDCLiquidity + usdcAmount

            var sharesToMint : UFix64 = 0.0
            if LiquidationPool.totalShares == 0.0 {
                sharesToMint = usdValue
            } else {
                let totalPoolValueUSD = self.getTotalPoolValueUSD(ethPrice: ethPrice)
                sharesToMint = (usdValue * LiquidationPool.totalShares) / totalPoolValueUSD
            }
            
            // Update contributor info
            if LiquidationPool.contributors[contributor] == nil {
                LiquidationPool.contributors[contributor] = ContributorInfo(
                    address: contributor,
                    shares: sharesToMint,
                    ethDeposited: 0.0,
                    usdcDeposited: usdcAmount,
                    flowDeposited: 0.0
                )
            } else {
                LiquidationPool.contributors[contributor]!.addShares(
                    amount: sharesToMint,
                    ethAmount: 0.0,
                    usdcAmount: usdcAmount,
                    flowAmount: 0.0
                )
            }
            
            // Update pool state
            LiquidationPool.totalShares = LiquidationPool.totalShares + sharesToMint
            
            emit USDCContributionAdded(
                contributor: contributor,
                amount: usdcAmount,
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
            
            // Get ETH price for calculating total pool value
            let ethPriceStr = Oracle.getPrice(symbol: "ETH", payment: <-oraclePayment)
            let ethPrice = UFix64.fromString(ethPriceStr) ?? panic("Invalid ETH price from oracle")
            
            // Flow is assumed 1:1 with USD
            let usdValue = flowAmount
            
            // Store Flow in pool
            LiquidationPool.flowVault.deposit(from: <-flowVault)
            LiquidationPool.totalFlowLiquidity = LiquidationPool.totalFlowLiquidity + flowAmount

            var sharesToMint : UFix64 = 0.0
            if LiquidationPool.totalShares == 0.0 {
                sharesToMint = usdValue
            } else {
                let totalPoolValueUSD = self.getTotalPoolValueUSD(ethPrice: ethPrice)
                sharesToMint = (usdValue * LiquidationPool.totalShares) / totalPoolValueUSD
            }
            
            // Update contributor info
            if LiquidationPool.contributors[contributor] == nil {
                LiquidationPool.contributors[contributor] = ContributorInfo(
                    address: contributor,
                    shares: sharesToMint,
                    ethDeposited: 0.0,
                    usdcDeposited: 0.0,
                    flowDeposited: flowAmount
                )
            } else {
                LiquidationPool.contributors[contributor]!.addShares(
                    amount: sharesToMint,
                    ethAmount: 0.0,
                    usdcAmount: 0.0,
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
        
        // Withdraw contribution (get back proportional ETH, USDC, and Flow)
        access(all) fun withdrawFromPool(
            shares: UFix64,
            contributor: Address,
            ethRecipient: &{FungibleToken.Receiver},
            usdcRecipient: &{FungibleToken.Receiver},
            flowRecipient: &{FungibleToken.Receiver}
        ) {
            pre {
                LiquidationPool.contributors[contributor] != nil: "Contributor not found"
                LiquidationPool.contributors[contributor]!.shares >= shares: "Insufficient shares"
                shares > 0.0: "Shares must be greater than 0"
                LiquidationPool.totalShares > 0.0: "No shares in pool"
            }
            
            // Calculate proportional amounts to return
            let shareRatio = shares / LiquidationPool.totalShares
            let ethAmount = shareRatio * LiquidationPool.totalETHLiquidity
            let usdcAmount = shareRatio * LiquidationPool.totalUSDCLiquidity
            let flowAmount = shareRatio * LiquidationPool.totalFlowLiquidity
            
            // Ensure we have enough liquidity
            assert(ethAmount <= LiquidationPool.ethVault.balance, 
                message: "Insufficient ETH in pool. Available: ".concat(LiquidationPool.ethVault.balance.toString()))
            assert(usdcAmount <= LiquidationPool.usdcVault.balance, 
                message: "Insufficient USDC in pool. Available: ".concat(LiquidationPool.usdcVault.balance.toString()))
            assert(flowAmount <= LiquidationPool.flowVault.balance, 
                message: "Insufficient Flow in pool. Available: ".concat(LiquidationPool.flowVault.balance.toString()))
            
            // Withdraw and send tokens
            if ethAmount > 0.0 {
                let ethToReturn <- LiquidationPool.ethVault.withdraw(amount: ethAmount)
                ethRecipient.deposit(from: <-ethToReturn)
            }
            
            if usdcAmount > 0.0 {
                let usdcToReturn <- LiquidationPool.usdcVault.withdraw(amount: usdcAmount)
                usdcRecipient.deposit(from: <-usdcToReturn)
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
            LiquidationPool.totalUSDCLiquidity = LiquidationPool.totalUSDCLiquidity - usdcAmount
            LiquidationPool.totalFlowLiquidity = LiquidationPool.totalFlowLiquidity - flowAmount
            
            emit ContributionWithdrawn(
                contributor: contributor,
                sharesRedeemed: shares,
                ethAmount: ethAmount,
                usdcAmount: usdcAmount,
                flowAmount: flowAmount
            )
        }

    access(all) fun executeHardLiquidation(
            positionId: UInt64,
            debtTokenType: String,
        ) {
            pre {
                debtTokenType == "FLOW" || debtTokenType == "USDC" || debtTokenType == "ETH": "Invalid debt token type"
            }

            let oraclePayment <- LiquidationPool.flowVault.withdraw(amount: BandOracle.getFee())

            // Update cached prices
            TimeLendingProtocol2.updateCachedPrice(symbol: "ETH", payment: <-oraclePayment)
            
            // Get position info
            let position = TimeLendingProtocol2.getBorrowingPosition(id: positionId)
                ?? panic("Position not found")
            
            assert(position.isActive, message: "Position is not active")
            
            // Calculate total debt with interest
            let timeElapsed = getCurrentBlock().timestamp - position.timestamp
            let baseInterestRate = 0.05  // 5% annual
            let interest = position.borrowAmount * baseInterestRate * timeElapsed / 31536000.0
            let totalDebt = position.borrowAmount + interest
            
            // Create repayment vault based on debt token type
            var repaymentVault: @{FungibleToken.Vault}? <- nil
            
            if debtTokenType == "FLOW" {
                assert(totalDebt <= LiquidationPool.totalFlowLiquidity,
                    message: "Insufficient Flow liquidity. Required: ".concat(totalDebt.toString()))
                repaymentVault <-! LiquidationPool.flowVault.withdraw(amount: totalDebt)
                LiquidationPool.totalFlowLiquidity = LiquidationPool.totalFlowLiquidity - totalDebt
            } else if debtTokenType == "USDC" {
                assert(totalDebt <= LiquidationPool.totalUSDCLiquidity,
                    message: "Insufficient USDC liquidity. Required: ".concat(totalDebt.toString()))
                repaymentVault <-! LiquidationPool.usdcVault.withdraw(amount: totalDebt)
                LiquidationPool.totalUSDCLiquidity = LiquidationPool.totalUSDCLiquidity - totalDebt
            } else {
                assert(totalDebt <= LiquidationPool.totalETHLiquidity,
                    message: "Insufficient ETH liquidity. Required: ".concat(totalDebt.toString()))
                repaymentVault <-! LiquidationPool.ethVault.withdraw(amount: totalDebt)
                LiquidationPool.totalETHLiquidity = LiquidationPool.totalETHLiquidity - totalDebt
            }

            let collateralType = TimeLendingProtocol2.getBorrowingPosition(id: positionId)?.collateralType ?? panic("Could not get collateral type")

            var collateralRecipient: &{FungibleToken.Receiver} = LiquidationPool.account.capabilities.get<&{FungibleToken.Receiver}>(WrappedETH1.ReceiverPublicPath)
                .borrow() ?? panic("Could not borrow ETH receiver capability")

            if collateralType.identifier.contains("ETH") {
                collateralRecipient = LiquidationPool.account.capabilities.get<&{FungibleToken.Receiver}>(WrappedETH1.ReceiverPublicPath)
                .borrow() ?? panic("Could not borrow ETH receiver capability")
            } else if collateralType.identifier.contains("USDC") {
                collateralRecipient = LiquidationPool.account.capabilities.get<&{FungibleToken.Receiver}>(WrappedUSDC1.ReceiverPublicPath)
                .borrow() ?? panic("Could not borrow USDC receiver capability")
            } else if collateralType.identifier.contains("FLOW") {
                collateralRecipient = LiquidationPool.account.capabilities.get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                .borrow() ?? panic("Could not borrow Flow receiver capability") 
            } else {
                panic("Unsupported collateral type")
            }
            // Execute hard liquidation
            TimeLendingProtocol2.hardLiquidateOverduePosition(
                positionId: positionId,
                liquidator: self.account.address,
                repaymentVault: <-repaymentVault!,
                liquidatorRecipient: collateralRecipient
            )
            
            // Calculate profit
            let ethPrice = TimeLendingProtocol2.getCachedPrice(symbol: "ETH") ?? 2000.0
            let collateralValueUSD = position.collateralAmount * ethPrice
            let profitInUSD = collateralValueUSD - totalDebt
            
            emit LiquidationExecuted(
                positionId: positionId,
                liquidationType: "HardLiquidation",
                liquidator: self.account.address,
                collateralReceived: position.collateralAmount,
                collateralType: collateralType.identifier,
                debtRepaid: totalDebt,
                profitGenerated: profitInUSD
            )
            
            emit CollateralCollected(
                tokenType: "ETH",
                amount: position.collateralAmount,
                usdValue: collateralValueUSD
            )
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
        self.totalUSDCLiquidity = 0.0
        self.totalFlowLiquidity = 0.0
        self.pendingFlowRewards = 0.0
        self.contributors = {}
        
        // Create empty vaults
        self.flowVault <- FlowToken.createEmptyVault(vaultType: Type<@FlowToken.Vault>()) as! @FlowToken.Vault
        self.ethVault <- WrappedETH1.createEmptyVault(vaultType: Type<@WrappedETH1.Vault>())
        self.usdcVault <- WrappedUSDC1.createEmptyVault(vaultType: Type<@WrappedUSDC1.Vault>())        
        // Create collateral vaults
        self.collateralETHVault <- WrappedETH1.createEmptyVault(vaultType: Type<@WrappedETH1.Vault>())
        self.collateralUSDCVault <- WrappedUSDC1.createEmptyVault(vaultType: Type<@WrappedUSDC1.Vault>())
        
        // Create and save admin
        let admin <- create PoolAdmin()
        self.account.storage.save(<-admin, to: self.PoolAdminStoragePath)
    }
}