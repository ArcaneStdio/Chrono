import FungibleToken from 0xee82856bf20e2aa6
import FlowToken from 0x0ae53cb6e3f42a79
import "IWrappedToken"
import "Oracle"

access(all) contract TimeLendingProtocol {
    // Events
    access(all) event LendingPositionCreated(lender: Address, amount: UFix64, tokenType: Type, positionId: UInt64)
    access(all) event BorrowingPositionCreated(borrower: Address, collateralAmount: UFix64, borrowAmount: UFix64, positionId: UInt64, durationMinutes: UInt64, calculatedLTV: UFix64 , liquidationThreshold: UFix64)
    access(all) event PositionLiquidated(positionId: UInt64, liquidator: Address, liquidationType: String)
    access(all) event PositionRepaid(positionId: UInt64, borrower: Address, totalRepayment: UFix64)
    access(all) event LTVParametersUpdated(a: UFix64, b: UFix64, c: UFix64)
    
    // Storage paths
    access(all) let AdminStoragePath: StoragePath
    access(all) let LendingManagerStoragePath: StoragePath
    access(all) let BorrowingManagerStoragePath: StoragePath
    access(all) let LiquidationManagerStoragePath: StoragePath

    access(all) var cachedPrices: {String: UFix64}  // symbol -> price
    access(all) var lastPriceUpdate: {String: UFix64}  // symbol -> timestamp
    
    // Protocol parameters
    access(all) var maxLTV: UFix64  // Maximum Loan-to-Value ratio (e.g., 0.75 for 75%)
    access(all) var liquidationThreshold: UFix64  // Liquidation threshold (e.g., 0.85 for 85%)
    access(all) var baseInterestRate: UFix64  // Base interest rate
    
    // Dynamic LTV formula parameters: a + b*2^(c*t)
    // Where t is duration in minutes
    access(all) var ltvFormulaA: UFix64  // Base LTV component 
    access(all) var ltvFormulaB: UFix64  // Exponential coefficient
    access(all) var ltvFormulaC: Int64   // Time multiplier (can be negative for decay)
    
    access(all) var ltFormulaA: UFix64  // Base LTV component 
    access(all) var ltFormulaB: UFix64  // Exponential coefficient
    access(all) var ltFormulaC: Int64   // Time multiplier (can be negative for decay)

    // Position counters
    access(all) var nextLendingPositionId: UInt64
    access(all) var nextBorrowingPositionId: UInt64
    
    // Lending position structure
    access(all) struct LendingPosition {
        access(all) let id: UInt64
        access(all) let lender: Address
        access(all) let tokenType: Type
        access(all) let amount: UFix64
        access(all) let timestamp: UFix64
        access(all) var isActive: Bool
        
        init(id: UInt64, lender: Address, tokenType: Type, amount: UFix64) {
            self.id = id
            self.lender = lender
            self.tokenType = tokenType
            self.amount = amount
            self.timestamp = getCurrentBlock().timestamp
            self.isActive = true
        }
        
        access(all) fun deactivate() {
            self.isActive = false
        }
    }
    
    // Enhanced Borrowing position structure
    access(all) struct BorrowingPosition {
        access(all) let id: UInt64
        access(all) let borrower: Address
        access(all) let collateralType: Type
        access(all) let collateralAmount: UFix64
        access(all) let borrowTokenType: Type
        access(all) let borrowAmount: UFix64
        access(all) let durationMinutes: UInt64  //Duration in minutes
        access(all) let calculatedLTV: UFix64  //LTV used for this position
        access(all) let repaymentDeadline: UFix64
        access(all) let timestamp: UFix64
        access(all) var isActive: Bool
        access(all) let liquidationThreshold: UFix64
        access(all) var healthFactor: UFix64
        
        init(
            id: UInt64, 
            borrower: Address, 
            collateralType: Type, 
            collateralAmount: UFix64, 
            borrowTokenType: Type, 
            borrowAmount: UFix64, 
            durationMinutes: UInt64,
            calculatedLTV: UFix64,
            liquidationThreshold: UFix64,
            healthFactor: UFix64
        ) {
            self.id = id
            self.borrower = borrower
            self.collateralType = collateralType
            self.collateralAmount = collateralAmount
            self.borrowTokenType = borrowTokenType
            self.borrowAmount = borrowAmount
            self.durationMinutes = durationMinutes
            self.calculatedLTV = calculatedLTV
            self.timestamp = getCurrentBlock().timestamp
            self.repaymentDeadline = self.timestamp + UFix64(durationMinutes * 60) // Convert minutes to seconds
            self.isActive = true
            self.healthFactor = healthFactor
            self.liquidationThreshold = liquidationThreshold
        }
        
        access(all) fun updateHealthFactor(newHealthFactor: UFix64) {
            self.healthFactor = newHealthFactor
        }
        
        access(all) fun close() {
            self.isActive = false
        }
        
        access(all) view fun isOverdue(): Bool {
            return getCurrentBlock().timestamp > self.repaymentDeadline
        }
        
        access(all) view fun getRemainingTime(): UFix64 {
            let currentTime = getCurrentBlock().timestamp
            if currentTime >= self.repaymentDeadline {
                return 0.0
            }
            return self.repaymentDeadline - currentTime
        }
    }
    
    // Protocol vaults for different token types
    // Using proper interface syntax for FungibleToken.Vault
    access(all) var lendingVaults: @{Type: {FungibleToken.Vault}}
    access(all) var collateralVaults: @{Type: {FungibleToken.Vault}}
    
    // Position tracking
    access(all) var lendingPositions: {UInt64: LendingPosition}
    access(all) var borrowingPositions: {UInt64: BorrowingPosition}
    
    // Utility function to calculate dynamic LTV based on duration in minutes
    // Formula: a + b*2^(c*t) where t is duration in minutes
    access(all) view fun calculateDynamicLTV(durationInMinutes: UInt64): UFix64 {
        // Calculate c*t first
        let exponentValue = self.ltvFormulaC * Int64(durationInMinutes)
        
        // Calculate 2^(c*t) using binary shift operations
        // Since we're dealing with potentially negative exponents, we need to handle both cases
        var powerOfTwo: UFix64 = 0.0
        
        if exponentValue >= 0 {
            // Positive exponent: 2^n = 1 << n
            // Convert to UInt64 for shifting (max shift is 63 bits to avoid overflow)
            let shiftAmount = UInt64(exponentValue)
            if shiftAmount > 63 {
                // Prevent overflow - cap at maximum reasonable value
                powerOfTwo = UFix64(UInt64(1) << 63)
            } else {
                powerOfTwo = UFix64(UInt64(1) << shiftAmount)
            }
        } else {
            // Negative exponent: 2^(-n) = 1 / (2^n) = 1 / (1 << n)
            let positiveExponent = UInt64(-exponentValue)
            if positiveExponent > 63 {
                // Very small value, essentially 0
                powerOfTwo = 0.0
            } else {
                let denominator = UFix64(UInt64(1) << positiveExponent)
                powerOfTwo = 1.0 / denominator
            }
        }
        
        let calculatedLTV = self.ltvFormulaA + self.ltvFormulaB * powerOfTwo
        
        // Ensure LTV doesn't exceed maximum allowed
        if calculatedLTV > self.maxLTV {
            return self.maxLTV
        }
        
        // Ensure LTV is not negative
        if calculatedLTV < 0.0 {
            return 0.0
        }
        
        return calculatedLTV
    }

    // Soft Liquidation - Partial liquidation when health factor < 1.0
// Liquidates only enough to bring health factor back to 1.1
access(all) fun softLiquidatePosition(
    positionId: UInt64,
    liquidator: Address,
    repaymentVault: @{FungibleToken.Vault},
    liquidatorRecipient: &{FungibleToken.Receiver}
) {
    pre {
        TimeLendingProtocol.borrowingPositions[positionId] != nil: "Position does not exist"
        TimeLendingProtocol.borrowingPositions[positionId]!.isActive: "Position is not active"
        TimeLendingProtocol.borrowingPositions[positionId]!.healthFactor < 1.0: "Position is healthy, health factor must be < 1.0"
    }
    
    let position = TimeLendingProtocol.borrowingPositions[positionId]!
    
    // Calculate how much debt needs to be repaid to reach health factor of 1.1
    // health_factor = (collateral_value * liquidation_threshold) / debt_value
    // Target: 1.1 = (collateral_value * liquidation_threshold) / new_debt_value
    // new_debt_value = (collateral_value * liquidation_threshold) / 1.1
    
    let currentDebt = position.borrowAmount
    let collateralValue = position.collateralAmount // Simplified: assuming 1:1 price ratio
    let targetHealthFactor: UFix64 = 1.1
    
    // Calculate target debt to achieve health factor of 1.1
    let targetDebt = (collateralValue * position.liquidationThreshold) / targetHealthFactor
    
    // Amount of debt to be repaid by liquidator
    let debtToRepay = currentDebt - targetDebt
    
    // Ensure repayment vault has enough
    if repaymentVault.balance < debtToRepay {
        let balance = repaymentVault.balance
        destroy repaymentVault
        panic("Insufficient repayment. Required: ".concat(debtToRepay.toString()).concat(", Provided: ").concat(balance.toString()))
    }
    
    // Calculate collateral to give to liquidator (with liquidation bonus of 5%)
    let liquidationBonus: UFix64 = 1.05
    let collateralToLiquidator = debtToRepay * liquidationBonus
    
    // Ensure we don't try to withdraw more collateral than available
    if collateralToLiquidator > position.collateralAmount {
        destroy repaymentVault
        panic("Calculated collateral exceeds available collateral")
    }
    
    // Deposit repayment into lending vault
    if TimeLendingProtocol.lendingVaults[position.borrowTokenType] != nil {
        let vaultRef = (&TimeLendingProtocol.lendingVaults[position.borrowTokenType] as &{FungibleToken.Vault}?)!
        let exactRepayment <- repaymentVault.withdraw(amount: debtToRepay)
        vaultRef.deposit(from: <-exactRepayment)
    } else {
        let exactRepayment <- repaymentVault.withdraw(amount: debtToRepay)
        TimeLendingProtocol.lendingVaults[position.borrowTokenType] <-! exactRepayment
    }
    
    // Return excess repayment to liquidator if any
    if repaymentVault.balance > 0.0 {
        liquidatorRecipient.deposit(from: <-repaymentVault)
    } else {
        destroy repaymentVault
    }
    
    // Transfer collateral to liquidator
    if let collateralVaultRef = &TimeLendingProtocol.collateralVaults[position.collateralType] as auth(FungibleToken.Withdraw) &{FungibleToken.Vault}? {
        let collateral <- collateralVaultRef.withdraw(amount: collateralToLiquidator)
        liquidatorRecipient.deposit(from: <-collateral)
    }

    let newHealthFactor = self.calculateHealthFactor(positionId: positionId)
    
    // Update position with new amounts
    let newCollateralAmount = position.collateralAmount - collateralToLiquidator
    let newBorrowAmount = position.borrowAmount - debtToRepay
    
    // Update borrowing position (create new struct with updated values)
    let updatedPosition = BorrowingPosition(
        id: position.id,
        borrower: position.borrower,
        collateralType: position.collateralType,
        collateralAmount: newCollateralAmount,
        borrowTokenType: position.borrowTokenType,
        borrowAmount: newBorrowAmount,
        durationMinutes: position.durationMinutes,
        calculatedLTV: position.calculatedLTV,
        liquidationThreshold: position.liquidationThreshold,
        healthFactor: newHealthFactor
    )
    updatedPosition.updateHealthFactor(newHealthFactor: targetHealthFactor)
    TimeLendingProtocol.borrowingPositions[positionId] = updatedPosition
    
    emit PositionLiquidated(positionId: positionId, liquidator: liquidator, liquidationType: "SoftLiquidation")
}

// Hard Liquidation - Full liquidation for overdue positions
// Liquidates entire position if repayment deadline has passed
access(all) fun hardLiquidateOverduePosition(
    positionId: UInt64,
    liquidator: Address,
    repaymentVault: @{FungibleToken.Vault},
    liquidatorRecipient: &{FungibleToken.Receiver}
) {
    pre {
        TimeLendingProtocol.borrowingPositions[positionId] != nil: "Position does not exist"
        TimeLendingProtocol.borrowingPositions[positionId]!.isActive: "Position is not active"
        TimeLendingProtocol.borrowingPositions[positionId]!.isOverdue(): "Position is not overdue yet"
    }
    
    let position = TimeLendingProtocol.borrowingPositions[positionId]!
    
    // Calculate total debt including interest
    let timeElapsed = getCurrentBlock().timestamp - position.timestamp
    let annualRate = TimeLendingProtocol.baseInterestRate
    let interest = position.borrowAmount * annualRate * timeElapsed / 31536000.0
    let totalDebt = position.borrowAmount + interest
    
    // Liquidator must repay the full debt
    if repaymentVault.balance < totalDebt {
        let balance = repaymentVault.balance
        destroy repaymentVault
        panic("Insufficient repayment for full liquidation. Required: ".concat(totalDebt.toString()).concat(", Provided: ").concat(balance.toString()))
    }
    
    // Deposit full repayment into lending vault
    if TimeLendingProtocol.lendingVaults[position.borrowTokenType] != nil {
        let vaultRef = (&TimeLendingProtocol.lendingVaults[position.borrowTokenType] as &{FungibleToken.Vault}?)!
        let exactRepayment <- repaymentVault.withdraw(amount: totalDebt)
        vaultRef.deposit(from: <-exactRepayment)
    } else {
        let exactRepayment <- repaymentVault.withdraw(amount: totalDebt)
        TimeLendingProtocol.lendingVaults[position.borrowTokenType] <-! exactRepayment
    }
    
    // Return excess repayment to liquidator if any
    if repaymentVault.balance > 0.0 {
        liquidatorRecipient.deposit(from: <-repaymentVault)
    } else {
        destroy repaymentVault
    }
    
    // Transfer ALL collateral to liquidator (hard liquidation penalty for overdue)
    if let collateralVaultRef = &TimeLendingProtocol.collateralVaults[position.collateralType] as auth(FungibleToken.Withdraw) &{FungibleToken.Vault}? {
        let collateral <- collateralVaultRef.withdraw(amount: position.collateralAmount)
        liquidatorRecipient.deposit(from: <-collateral)
    }
    
    // Close position completely
    TimeLendingProtocol.borrowingPositions[positionId]!.close()
    
    emit PositionLiquidated(positionId: positionId, liquidator: liquidator, liquidationType: "HardLiquidation")
}

    access(all) view fun calculateDynamicLT(durationInMinutes: UInt64): UFix64 {
        // Calculate c*t first
        let exponentValue = self.ltFormulaC * Int64(durationInMinutes)
        
        // Calculate 2^(c*t) using binary shift operations
        // Since we're dealing with potentially negative exponents, we need to handle both cases
        var powerOfTwo: UFix64 = 0.0
        
        if exponentValue >= 0 {
            // Positive exponent: 2^n = 1 << n
            // Convert to UInt64 for shifting (max shift is 63 bits to avoid overflow)
            let shiftAmount = UInt64(exponentValue)
            if shiftAmount > 63 {
                // Prevent overflow - cap at maximum reasonable value
                powerOfTwo = UFix64(UInt64(1) << 63)
            } else {
                powerOfTwo = UFix64(UInt64(1) << shiftAmount)
            }
        } else {
            // Negative exponent: 2^(-n) = 1 / (2^n) = 1 / (1 << n)
            let positiveExponent = UInt64(-exponentValue)
            if positiveExponent > 63 {
                // Very small value, essentially 0
                powerOfTwo = 0.0
            } else {
                let denominator = UFix64(UInt64(1) << positiveExponent)
                powerOfTwo = 1.0 / denominator
            }
        }
        
        let calculatedLT = self.ltFormulaA + self.ltFormulaB * powerOfTwo
        
        // Ensure LTV doesn't exceed maximum allowed
        if calculatedLT > self.maxLT {
            return self.maxLT
        }
        
        // Ensure LTV is not negative
        if calculatedLT < 0.0 {
            return 0.0
        }
        
        return calculatedLT
    }

    // Admin resource for protocol management
    access(all) resource Admin {
        
        access(all) fun updateLTV(newLTV: UFix64) {
            pre {
                newLTV <= 1.0: "LTV cannot exceed 100%"
            }
            TimeLendingProtocol.maxLTV = newLTV
        }
        
        access(all) fun updateLiquidationThreshold(newThreshold: UFix64) {
            TimeLendingProtocol.liquidationThreshold = newThreshold
        }
        
        access(all) fun updateInterestRate(newRate: UFix64) {
            TimeLendingProtocol.baseInterestRate = newRate
        }
        
        access(all) fun updateLTVFormulaParameters(a: UFix64, b: UFix64, c: Int64) {
            TimeLendingProtocol.ltvFormulaA = a
            TimeLendingProtocol.ltvFormulaB = b
            TimeLendingProtocol.ltvFormulaC = c
            
            emit LTVParametersUpdated(a: a, b: b, c: UFix64(c))
        }
        
        access(all) fun addSupportedToken(tokenType: Type, vault: @{FungibleToken.Vault}) {
            TimeLendingProtocol.lendingVaults[tokenType] <-! vault
        }

        // TODO: Ask raptor if anything goes in these 2 functions
        access(all) fun createMinter(tokenType: Type): @{IWrappedToken.Minter}? {
            // Implementation would depend on specific wrapped token contract
            return nil
        }
        
        access(all) fun createBurner(tokenType: Type): @{IWrappedToken.Burner}? {
            // Implementation would depend on specific wrapped token contract
            return nil
        }
    }
    
    // Lending Manager resource
    access(all) resource LendingManager {
        
        access(all) fun createLendingPosition(
            tokenVault: @{FungibleToken.Vault},
            lender: Address
        ): UInt64 {
            let positionId = TimeLendingProtocol.nextLendingPositionId
            TimeLendingProtocol.nextLendingPositionId = positionId + 1
            
            let tokenType = tokenVault.getType()
            let amount = tokenVault.balance
            
            // Store the tokens in appropriate vault
            if TimeLendingProtocol.lendingVaults[tokenType] != nil {
                let vaultRef = (&TimeLendingProtocol.lendingVaults[tokenType] as &{FungibleToken.Vault}?)!
                vaultRef.deposit(from: <-tokenVault)
            } else {
                // Create new vault for this token type
                TimeLendingProtocol.lendingVaults[tokenType] <-! tokenVault
            }
            
            // Create lending position
            let position = LendingPosition(
                id: positionId,
                lender: lender,
                tokenType: tokenType,
                amount: amount
            )
            
            TimeLendingProtocol.lendingPositions[positionId] = position
            
            emit LendingPositionCreated(
                lender: lender,
                amount: amount,
                tokenType: tokenType,
                positionId: positionId
            )
            
            return positionId
        }
        
        // FIXED: Added proper entitlement to vault reference
        access(all) fun withdrawLending(positionId: UInt64, recipient: &{FungibleToken.Receiver}) {
            pre {
                TimeLendingProtocol.lendingPositions[positionId] != nil: "Position does not exist"
                TimeLendingProtocol.lendingPositions[positionId]!.isActive: "Position is not active"
            }
            
            let position = TimeLendingProtocol.lendingPositions[positionId]!
            let tokenType = position.tokenType
            
            // Get an authorized reference with Withdraw entitlement
            if let vaultRef = &TimeLendingProtocol.lendingVaults[tokenType] as auth(FungibleToken.Withdraw) &{FungibleToken.Vault}? {
                let withdrawnTokens <- vaultRef.withdraw(amount: position.amount)
                recipient.deposit(from: <-withdrawnTokens)
                
                // Deactivate position
                TimeLendingProtocol.lendingPositions[positionId]!.deactivate()
            }
        }
    }
    
    // Enhanced Borrowing Manager resource
    access(all) resource BorrowingManager {
        
        access(all) fun createBorrowingPosition(
            collateralVault: @{FungibleToken.Vault},
            borrowTokenType: Type,
            borrowAmount: UFix64,
            durationMinutes: UInt64,  // Duration in minutes
            borrower: Address
        ): UInt64? {
            let positionId = TimeLendingProtocol.nextBorrowingPositionId
            TimeLendingProtocol.nextBorrowingPositionId = positionId + 1
            
            let collateralType = collateralVault.getType()
            let collateralAmount = collateralVault.balance
            
            // Calculate dynamic LTV based on duration in minutes
            let calculatedLTV = TimeLendingProtocol.calculateDynamicLTV(durationInMinutes: durationMinutes)

            let liquidationThreshold = TimeLendingProtocol.calculateDynamicLT(durationInMinutes: durationMinutes)

            // Check LTV ratio (simplified - would need oracle for real prices)
            let maxBorrowAmount = collateralAmount * calculatedLTV
            if borrowAmount > maxBorrowAmount {
                destroy collateralVault
                return nil
            }
            
            // Store collateral
            if TimeLendingProtocol.collateralVaults[collateralType] != nil {
                let vaultRef = (&TimeLendingProtocol.collateralVaults[collateralType] as &{FungibleToken.Vault}?)!
                vaultRef.deposit(from: <-collateralVault)
            } else {
                TimeLendingProtocol.collateralVaults[collateralType] <-! collateralVault
            }
            
            // Create borrowing position
            let position = BorrowingPosition(
                id: positionId,
                borrower: borrower,
                collateralType: collateralType,
                collateralAmount: collateralAmount,
                borrowTokenType: borrowTokenType,
                borrowAmount: borrowAmount,
                durationMinutes: durationMinutes,
                calculatedLTV: calculatedLTV,
                liquidationThreshold: liquidationThreshold
            )
            
            TimeLendingProtocol.borrowingPositions[positionId] = position
            
            emit BorrowingPositionCreated(
                borrower: borrower,
                collateralAmount: collateralAmount,
                borrowAmount: borrowAmount,
                positionId: positionId,
                durationMinutes: durationMinutes,
                calculatedLTV: calculatedLTV,
                liquidationThreshold: liquidationThreshold
            )
            
            TimeLendingProtocol.borrowingPositions[positionId] = position
            
            emit BorrowingPositionCreated(
                borrower: borrower,
                collateralAmount: collateralAmount,
                borrowAmount: borrowAmount,
                positionId: positionId,
                durationMinutes: durationMinutes,
                calculatedLTV: calculatedLTV,
                liquidationThreshold: liquidationThreshold
            )
            return positionId
        }
        
        // FIXED: Added proper entitlement to vault references
        access(all) fun repayLoan(
            positionId: UInt64,
            repaymentVault: @{FungibleToken.Vault},
            collateralRecipient: &{FungibleToken.Receiver}
        ) {
            pre {
                TimeLendingProtocol.borrowingPositions[positionId] != nil: "Position does not exist"
                TimeLendingProtocol.borrowingPositions[positionId]!.isActive: "Position is not active"
            }
            
            let position = TimeLendingProtocol.borrowingPositions[positionId]!
            
            // Calculate interest based on actual time elapsed
            let timeElapsed = getCurrentBlock().timestamp - position.timestamp
            let annualRate = TimeLendingProtocol.baseInterestRate
            let interest = position.borrowAmount * annualRate * timeElapsed / 31536000.0 // per year
            let totalRepayment = position.borrowAmount + interest
            
            // Check if repayment is sufficient
            if repaymentVault.balance < totalRepayment {
                let repaymentBalance = repaymentVault.balance
                destroy repaymentVault
                panic("Insufficient repayment amount. Required: ".concat(totalRepayment.toString()).concat(", Provided: ").concat(repaymentBalance.toString()))
            } else {
                if TimeLendingProtocol.lendingVaults[position.borrowTokenType] != nil {
                    let vaultRef = (&TimeLendingProtocol.lendingVaults[position.borrowTokenType] as &{FungibleToken.Vault}?)!
                    
                    // If repayment is more than required, withdraw the exact amount needed
                    if repaymentVault.balance > totalRepayment {
                        let exactRepayment <- repaymentVault.withdraw(amount: totalRepayment)
                        vaultRef.deposit(from: <-exactRepayment)
                        // Return excess to user (this would need to be handled in transaction)
                        destroy repaymentVault
                    } else {
                        vaultRef.deposit(from: <-repaymentVault)
                    }
                } else {
                    // If no vault exists, create one with the repayment
                    TimeLendingProtocol.lendingVaults[position.borrowTokenType] <-! repaymentVault
                }
            }
            
            // Return collateral to borrower using authorized reference
            if let collateralVaultRef = &TimeLendingProtocol.collateralVaults[position.collateralType] as auth(FungibleToken.Withdraw) &{FungibleToken.Vault}? {
                let collateral <- collateralVaultRef.withdraw(amount: position.collateralAmount)
                collateralRecipient.deposit(from: <-collateral)
            }
            
            // Close position
            TimeLendingProtocol.borrowingPositions[positionId]!.close()
            
            emit PositionRepaid(positionId: positionId, borrower: position.borrower, totalRepayment: totalRepayment)
        }
    }
    
    // Liquidation Manager resource - modular structure for future implementation
    access(all) resource LiquidationManager {
        
        // Time-based liquidation (for overdue positions) - to be implemented with stability pool
        access(all) fun liquidateOverduePosition(
            positionId: UInt64,
            liquidator: Address
        ) {
            pre {
                TimeLendingProtocol.borrowingPositions[positionId] != nil: "Position does not exist"
                TimeLendingProtocol.borrowingPositions[positionId]!.isActive: "Position is not active"
                TimeLendingProtocol.borrowingPositions[positionId]!.isOverdue(): "Position is not overdue"
            }
            
            // TODO: Implement stability pool liquidation logic
            // This will be stricter and instant liquidation
            self.executeStabilityPoolLiquidation(positionId: positionId, liquidator: liquidator)
        }
        
        access(all) fun liquidateUnhealthyPosition(
            positionId: UInt64,
            liquidator: Address,
            liquidatorRecipient: &{FungibleToken.Receiver}
        ) {
            pre {
                TimeLendingProtocol.borrowingPositions[positionId] != nil: "Position does not exist"
                TimeLendingProtocol.borrowingPositions[positionId]!.isActive: "Position is not active"
                TimeLendingProtocol.borrowingPositions[positionId]!.healthFactor < TimeLendingProtocol.liquidationThreshold: "Position is healthy"
            }
            
            // TODO: Implement Euler-style liquidation logic
            // This will be more lenient to the borrower
            self.executeEulerStyleLiquidation(positionId: positionId, liquidator: liquidator, liquidatorRecipient: liquidatorRecipient)
        }
        
        // Private function for stability pool liquidation - placeholder
        access(self) fun executeStabilityPoolLiquidation(positionId: UInt64, liquidator: Address) {
            // TODO: Implement stability pool liquidation
            // 1. Get position details
            // 2. Interact with stability pool
            // 3. Instantly liquidate collateral
            // 4. Distribute rewards/penalties
            
            let position = TimeLendingProtocol.borrowingPositions[positionId]!
            
            // Close position
            TimeLendingProtocol.borrowingPositions[positionId]!.close()
            
            emit PositionLiquidated(positionId: positionId, liquidator: liquidator, liquidationType: "StabilityPool")
        }
        
        // FIXED: Added proper entitlement to vault reference
        access(self) fun executeEulerStyleLiquidation(positionId: UInt64, liquidator: Address, liquidatorRecipient: &{FungibleToken.Receiver}) {
            // TODO: Implement Euler-style liquidation
            // 1. Calculate liquidation amounts based on health factor
            // 2. Allow partial liquidation
            // 3. Apply liquidation bonus/penalty
            // 4. Transfer appropriate amounts
            
            let position = TimeLendingProtocol.borrowingPositions[positionId]!
            
            // For now, transfer all collateral (will be refined in actual implementation)
            if let collateralVaultRef = &TimeLendingProtocol.collateralVaults[position.collateralType] as auth(FungibleToken.Withdraw) &{FungibleToken.Vault}? {
                let collateral <- collateralVaultRef.withdraw(amount: position.collateralAmount)
                liquidatorRecipient.deposit(from: <-collateral)
            }
            
            // Close position
            TimeLendingProtocol.borrowingPositions[positionId]!.close()
            
            emit PositionLiquidated(positionId: positionId, liquidator: liquidator, liquidationType: "EulerStyle")
        }
        
        // Function to check and update health factors - to be called by scheduled transactions
        access(all) fun updateHealthFactors(positionIds: [UInt64]) {
            // TODO: Implement health factor calculation using price oracles
            for positionId in positionIds {
                if let position = TimeLendingProtocol.borrowingPositions[positionId] {
                    if position.isActive {
                        // Calculate new health factor based on current prices
                        //extend to other currencies in the future
                        let newHealthFactor = self.calculateHealthFactor(positionId: positionId)
                        TimeLendingProtocol.borrowingPositions[positionId]!.updateHealthFactor(newHealthFactor: newHealthFactor)
                    }
                }
            }
        }
        
        // Private function to calculate health factor - placeholder
        access(self) view fun calculateHealthFactor(positionId: UInt64): UFix64 {
            //Plss debug Implemented by nawab with any flow setup
            // TODO: Implement with price oracles
            // health_factor = (collateral_value * liquidation_threshold) / debt_value
            return 1.0  // Placeholder
        }
    }
    
    // Public functions to get managers
    access(all) fun borrowLendingManager(): &LendingManager {
        return self.account.storage.borrow<&LendingManager>(from: self.LendingManagerStoragePath)
            ?? panic("Could not borrow lending manager")
    }
    
    access(all) fun borrowBorrowingManager(): &BorrowingManager {
        return self.account.storage.borrow<&BorrowingManager>(from: self.BorrowingManagerStoragePath)
            ?? panic("Could not borrow borrowing manager")
    }
    
    access(all) fun borrowLiquidationManager(): &LiquidationManager {
        return self.account.storage.borrow<&LiquidationManager>(from: self.LiquidationManagerStoragePath)
            ?? panic("Could not borrow liquidation manager")
    }
    
    // Enhanced view functions
    access(all) fun getLendingPosition(id: UInt64): LendingPosition? {
        return self.lendingPositions[id]
    }
    
    access(all) fun getBorrowingPosition(id: UInt64): BorrowingPosition? {
        return self.borrowingPositions[id]
    }
    
    access(all) fun getProtocolParameters(): {String: AnyStruct} {
        return {
            "maxLTV": self.maxLTV,
            "liquidationThreshold": self.liquidationThreshold,
            "baseInterestRate": self.baseInterestRate,
            "ltvFormulaA": self.ltvFormulaA,
            "ltvFormulaB": self.ltvFormulaB,
            "ltvFormulaC": self.ltvFormulaC
        }
    }
    
    access(all) view fun previewDynamicLTV(durationInMinutes: UInt64): UFix64 {
        return self.calculateDynamicLTV(durationInMinutes: durationInMinutes)
    }
    
    access(all) fun getOverduePositions(): [UInt64] {
        let overduePositions: [UInt64] = []
        for positionId in self.borrowingPositions.keys {
            if let position = self.borrowingPositions[positionId] {
                if position.isActive && position.isOverdue() {
                    overduePositions.append(positionId)
                }
            }
        }
        return overduePositions
    }

    access(all) fun updateCachedPrice(symbol: String, payment: @{FungibleToken.Vault}) {
        let priceStr = Oracle.getPrice(symbol: symbol, payment: <- payment)
        let price = UFix64.fromString(priceStr) ?? 0.0
        self.cachedPrices[symbol] = price
        self.lastPriceUpdate[symbol] = getCurrentBlock().timestamp
    }

    // Then use in calculateHealthFactor:
    access(contract) view fun calculateHealthFactor(positionId: UInt64): UFix64 {
        let position = TimeLendingProtocol.borrowingPositions[positionId]!
        
        let ethPrice = TimeLendingProtocol.cachedPrices["ETH"] ?? 2000.0
        let collateralValueUSD = position.collateralAmount * ethPrice
        let debtValueUSD = position.borrowAmount * 1.0  // assuming USD stablecoin
        
        if debtValueUSD == 0.0 {
            return 999.9
        }
        
        return (collateralValueUSD * position.liquidationThreshold) / debtValueUSD
    }
    
    init() {
        // Initialize storage paths
        self.AdminStoragePath = /storage/TimeLendingAdmin
        self.LendingManagerStoragePath = /storage/TimeLendingManager
        self.BorrowingManagerStoragePath = /storage/TimeBorrowingManager
        self.LiquidationManagerStoragePath = /storage/TimeLiquidationManager

        self.cachedPrices = {
            "ETH": 0.0
        }
        
        // Initialize last price update timestamps (set to contract deployment time)
        self.lastPriceUpdate = {
            "ETH": getCurrentBlock().timestamp
        }

        // Initialize protocol parameters
        self.maxLTV = 0.75  // 75%
        self.liquidationThreshold = 0.85  // 85%
        self.baseInterestRate = 0.05  // 5% per year
        
        // Initialize LTV formula parameters
        // Example: 0.3 + 0.4*2^(-1*t) gives higher LTV for shorter durations
        // With t in minutes: 1 minute -> LTV=0.5, 2 minutes -> LTV=0.4, 3 minutes -> LTV=0.35, etc.
        self.ltvFormulaA = 0.30  // Base LTV (30%)
        self.ltvFormulaB = 0.40  // Exponential coefficient (40%)
        self.ltvFormulaC = -1    // Negative time multiplier (decay by factor of 2 per minute)
        
        self.ltFormulaA = 0.35  // Base LTV (30%)
        self.ltFormulaB = 0.45  // Exponential coefficient (40%)
        self.ltFormulaC = -1    // Negative time multiplier (decay by factor of 2 per minute)

        // Initialize position counters 
        self.nextLendingPositionId = 1
        self.nextBorrowingPositionId = 1
        
        // Initialize empty collections
        self.lendingVaults <- {}
        self.collateralVaults <- {}
        self.lendingPositions = {}
        self.borrowingPositions = {}
        
        // Create and store admin resource
        let admin <- create Admin()
        self.account.storage.save(<-admin, to: self.AdminStoragePath)
        
        // Create and store managers
        let lendingManager <- create LendingManager()
        let borrowingManager <- create BorrowingManager()
        let liquidationManager <- create LiquidationManager()
        
        self.account.storage.save(<-lendingManager, to: self.LendingManagerStoragePath)
        self.account.storage.save(<-borrowingManager, to: self.BorrowingManagerStoragePath)
        self.account.storage.save(<-liquidationManager, to: self.LiquidationManagerStoragePath)
    }
}