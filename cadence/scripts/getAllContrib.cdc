import LiquidationPool from 0xe11cab85e85ae137

/// Script to get all contributors with their basic stats
/// Useful for leaderboard or contributors list on frontend
access(all) fun main(): [{String: AnyStruct}] {
    
    let contributors = LiquidationPool.getAllContributors()
    let poolStats = LiquidationPool.getPoolStats()
    let totalShares = poolStats["totalShares"]! as! UFix64
    
    let result: [{String: AnyStruct}] = []
    
    for address in contributors {
        let info = LiquidationPool.getContributorInfo(address: address)
        
        if info != nil {
            let contributorInfo = info!
            
            var sharePercentage = 0.0
            if totalShares > 0.0 {
                sharePercentage = (contributorInfo.shares / totalShares) * 100.0
            }

            result.append({
                "address": contributorInfo.address.toString(),
                "shares": contributorInfo.shares,
                "sharePercentage": sharePercentage,
                "totalETHDeposited": contributorInfo.totalETHDeposited,
                "totalUSDCDeposited": contributorInfo.totalUSDCDeposited,
                "totalFlowDeposited": contributorInfo.totalFlowDeposited,
                "claimableFlowRewards": contributorInfo.claimableFlowRewards,
                "totalFlowRewardsClaimed": contributorInfo.totalFlowRewardsClaimed,
                "joinedAt": contributorInfo.joinedAt
            })
        }
    }
    
    return result
}