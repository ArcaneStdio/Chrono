import LiquidationPool from 0xe11cab85e85ae137

/// Advanced analytics for the entire liquidation pool
/// Provides metrics for APY calculation, pool health, and more
/// @param ethPriceUSD: Current ETH price in USD
/// @param flowPriceUSD: Current FLOW price in USD
access(all) fun main(ethPriceUSD: UFix64, flowPriceUSD: UFix64): {String: AnyStruct} {
    
    let poolStats = LiquidationPool.getPoolStats()
    let liquidatablePositions = LiquidationPool.getLiquidatablePositions()
    
    // Extract values
    let totalShares = poolStats["totalShares"]! as! UFix64
    let totalETH = poolStats["totalETHLiquidity"]! as! UFix64
    let totalUSDC = poolStats["totalUSDCLiquidity"]! as! UFix64
    let totalFlow = poolStats["totalFlowLiquidity"]! as! UFix64
    let pendingRewards = poolStats["pendingFlowRewards"]! as! UFix64
    let collateralETH = poolStats["collateralETHBalance"]! as! UFix64
    let collateralUSDC = poolStats["collateralUSDCBalance"]! as! UFix64
    let contributorCount = poolStats["contributorCount"]! as! UFix64
    
    // Calculate USD values
    let ethValueUSD = totalETH * ethPriceUSD
    let flowValueUSD = totalFlow * flowPriceUSD
    let totalLiquidityUSD = ethValueUSD + totalUSDC + flowValueUSD
    
    let collateralETHValueUSD = collateralETH * ethPriceUSD
    let collateralUSDCValueUSD = collateralUSDC
    let totalCollateralValueUSD = collateralETHValueUSD + collateralUSDCValueUSD
    
    let pendingRewardsUSD = pendingRewards * flowPriceUSD
    
    // Calculate pool composition percentages
    var ethPercentage = 0.0
    if totalLiquidityUSD > 0.0 {
        ethPercentage = (ethValueUSD / totalLiquidityUSD) * 100.0
    }

    var usdcPercentage = 0.0
    if totalLiquidityUSD > 0.0 {
        usdcPercentage = (totalUSDC / totalLiquidityUSD) * 100.0
    }

    var flowPercentage = 0.0
    if totalLiquidityUSD > 0.0 {
        flowPercentage = (flowValueUSD / totalLiquidityUSD) * 100.0
    }
    
    // Get liquidatable positions
    let unhealthyPositions = liquidatablePositions["unhealthy"]! as! [UInt64]
    let overduePositions = liquidatablePositions["overdue"]! as! [UInt64]
    
    // Average investment per contributor
    var avgInvestmentUSD = 0.0
    if contributorCount > 0.0 {
        avgInvestmentUSD = totalLiquidityUSD / contributorCount
    }

    return {
        // Pool Size Metrics
        "poolSize": {
            "totalLiquidityUSD": totalLiquidityUSD,
            "totalShares": totalShares,
            "totalContributors": Int(contributorCount),
            "avgInvestmentPerContributor": avgInvestmentUSD
        },
        
        // Liquidity Breakdown
        "liquidity": {
            "eth": {
                "amount": totalETH,
                "valueUSD": ethValueUSD,
                "percentage": ethPercentage
            },
            "usdc": {
                "amount": totalUSDC,
                "valueUSD": totalUSDC,
                "percentage": usdcPercentage
            },
            "flow": {
                "amount": totalFlow,
                "valueUSD": flowValueUSD,
                "percentage": flowPercentage
            }
        },
        
        // Collateral Waiting to be Processed
        "unprocessedCollateral": {
            "eth": {
                "amount": collateralETH,
                "valueUSD": collateralETHValueUSD
            },
            "usdc": {
                "amount": collateralUSDC,
                "valueUSD": collateralUSDCValueUSD
            },
            "totalValueUSD": totalCollateralValueUSD
        },
        
        // Rewards
        "rewards": {
            "pendingFlow": pendingRewards,
            "pendingUSD": pendingRewardsUSD,
            "readyToDistribute": pendingRewards > 0.0
        },
        
        // Liquidation Opportunities
        "liquidationOpportunities": {
            "unhealthyPositions": unhealthyPositions.length,
            "overduePositions": overduePositions.length,
            "totalOpportunities": unhealthyPositions.length + overduePositions.length
        },
        
        // Pool Health Indicators
        "poolHealth": {
            "isActive": totalShares > 0.0,
            "hasLiquidity": totalLiquidityUSD > 0.0,
            "hasPendingCollateral": totalCollateralValueUSD > 0.0,
            "utilizationRate": 0.0 // Could be calculated if we track deployed capital
        },
        
        // Price Context (for reference)
        "priceContext": {
            "ethPriceUSD": ethPriceUSD,
            "flowPriceUSD": flowPriceUSD
        }
    }
}