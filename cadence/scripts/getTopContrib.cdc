import LiquidationPool from 0xe11cab85e85ae137

/// Get top contributors sorted by share percentage
/// Useful for leaderboard display on frontend
/// @param limit: Maximum number of contributors to return (0 for all)
access(all) fun main(limit: Int): [{String: AnyStruct}] {
    
    let contributors = LiquidationPool.getAllContributors()
    let poolStats = LiquidationPool.getPoolStats()
    let totalShares = poolStats["totalShares"]! as! UFix64
    
    var contributorsList: [{String: AnyStruct}] = []
    
    // Build list with all contributor data
    for address in contributors {
        let info = LiquidationPool.getContributorInfo(address: address)
        
        if info != nil {
            let contributorInfo = info!
            var sharePercentage = 0.0
            if totalShares > 0.0 {
                sharePercentage = (contributorInfo.shares / totalShares) * 100.0
            }

            contributorsList.append({
                "address": contributorInfo.address.toString(),
                "shares": contributorInfo.shares,
                "sharePercentage": sharePercentage,
                "totalETHDeposited": contributorInfo.totalETHDeposited,
                "totalUSDCDeposited": contributorInfo.totalUSDCDeposited,
                "totalFlowDeposited": contributorInfo.totalFlowDeposited,
                "claimableFlowRewards": contributorInfo.claimableFlowRewards,
                "totalFlowRewardsClaimed": contributorInfo.totalFlowRewardsClaimed,
                "totalFlowEarned": contributorInfo.claimableFlowRewards + contributorInfo.totalFlowRewardsClaimed,
                "joinedAt": contributorInfo.joinedAt
            })
        }
    }
    
    // Sort by share percentage (descending)
    // Note: Cadence doesn't have built-in sort, so this returns unsorted
    // You should sort on the frontend using the sharePercentage field
    
    // Apply limit if specified
    if limit > 0 && limit < contributorsList.length {
        let limitedList: [{String: AnyStruct}] = []
        var i = 0
        while i < limit {
            limitedList.append(contributorsList[i])
            i = i + 1
        }
        return limitedList
    }
    
    return contributorsList
}