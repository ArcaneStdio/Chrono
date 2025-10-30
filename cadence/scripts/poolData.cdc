import LiquidationPool from 0xe11cab85e85ae137

/// Script to get complete pool statistics including all vault data
/// Returns comprehensive pool information for frontend display
access(all) fun main(): {String: AnyStruct} {
    
    let poolStats = LiquidationPool.getPoolStats()
    
    return {
        // Main Pool Liquidity (available for liquidations)
        "totalShares": poolStats["totalShares"]!,
        "totalETHLiquidity": poolStats["totalETHLiquidity"]!,
        "totalUSDCLiquidity": poolStats["totalUSDCLiquidity"]!,
        "totalFlowLiquidity": poolStats["totalFlowLiquidity"]!,
        
        // Collateral Vaults (liquidated assets waiting to be converted)
        "collateralETHBalance": poolStats["collateralETHBalance"]!,
        "collateralUSDCBalance": poolStats["collateralUSDCBalance"]!,
        
        // Rewards
        "pendingFlowRewards": poolStats["pendingFlowRewards"]!,
        
        // Contributors
        "totalContributors": poolStats["contributorCount"]!,
        
        // Calculated Total Pool Value (in tokens, not USD)
        "totalPoolValue": {
            "eth": poolStats["totalETHLiquidity"]!,
            "usdc": poolStats["totalUSDCLiquidity"]!,
            "flow": poolStats["totalFlowLiquidity"]!
        },
        
        // Collateral waiting to be processed
        "unprocessedCollateral": {
            "eth": poolStats["collateralETHBalance"]!,
            "usdc": poolStats["collateralUSDCBalance"]!
        }
    }
}