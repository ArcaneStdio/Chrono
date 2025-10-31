import LiquidationPool from 0xe11cab85e85ae137

/// Script to get detailed investment information for a specific user
/// @param userAddress: The address of the user to query
/// Returns all investment and reward data for the user
access(all) fun main(userAddress: Address): {String: AnyStruct}? {
    
    let contributorInfo = LiquidationPool.getContributorInfo(address: userAddress)
    
    if contributorInfo == nil {
        return nil
    }
    
    let info = contributorInfo!
    let poolStats = LiquidationPool.getPoolStats()
    let totalShares = poolStats["totalShares"]! as! UFix64
    
    // Calculate user's share percentage
    var sharePercentage = 0.0
    if totalShares > 0.0 {
        sharePercentage = (info.shares / totalShares) * 100.0
    } else {
        sharePercentage = 0.0
    }

    // Calculate current value of user's shares (proportional to pool)
    var currentETHValue = 0.0
    
    if totalShares > 0.0 {
        currentETHValue = (info.shares / totalShares) * (poolStats["totalETHLiquidity"]! as! UFix64)
    } else {
        currentETHValue = 0.0
    }
    
    var currentUSDCValue = 0.0
    if totalShares > 0.0 {
        currentUSDCValue = (info.shares / totalShares) * (poolStats["totalUSDCLiquidity"]! as! UFix64)
    } else {
        currentUSDCValue = 0.0
    }

    var currentFlowValue = 0.0
    if totalShares > 0.0 {
        currentFlowValue = (info.shares / totalShares) * (poolStats["totalFlowLiquidity"]! as! UFix64)
    } else {
        currentFlowValue = 0.0
    }
    
    return {
        // Basic Info
        "userAddress": info.address.toString(),
        "joinedAt": info.joinedAt,
        "isActive": info.shares > 0.0,
        
        // Shares
        "shares": info.shares,
        "sharePercentage": sharePercentage,
        
        // Original Deposits
        "deposited": {
            "eth": info.totalETHDeposited,
            "usdc": info.totalUSDCDeposited,
            "flow": info.totalFlowDeposited,
            "total": {
                "eth": info.totalETHDeposited,
                "usdc": info.totalUSDCDeposited,
                "flow": info.totalFlowDeposited
            }
        },
        
        // Current Value (what user would get if they withdraw now)
        "currentValue": {
            "eth": currentETHValue,
            "usdc": currentUSDCValue,
            "flow": currentFlowValue
        },
        
        // Profit/Loss (current value - deposited)
        "profitLoss": {
            "eth": info.totalETHDeposited,
            "usdc": info.totalUSDCDeposited,
            "flow": info.totalFlowDeposited
        },
        
        // Rewards
        "rewards": {
            "claimableFlow": info.claimableFlowRewards,
            "totalFlowClaimed": info.totalFlowRewardsClaimed,
            "totalFlowEarned": info.claimableFlowRewards + info.totalFlowRewardsClaimed
        }
    }
}