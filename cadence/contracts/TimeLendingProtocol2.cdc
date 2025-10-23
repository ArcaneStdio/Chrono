import FungibleToken from 0xee82856bf20e2aa6
import FlowToken from 0x0ae53cb6e3f42a79
import "IWrappedToken"
import "Oracle"

access(all) contract TimeLendingProtocol {
    // Events
    access(all) event LendingPositionCreated(lender: Address, amount: UFix64, tokenType: Type, positionId: UInt64)
    access(all) event BorrowingPositionCreated(borrower: Address, collateralAmount: UFix64, borrowAmount: UFix64, positionId: UInt64, durationMinutes: UInt64, calculatedLTV: UFix64, liquidationThreshold: UFix64, healthFactor: UFix64)
    access(all) event PositionLiquidated(positionId: UInt64, liquidator: Address, liquidationType: String, collateralLiquidated: UFix64, debtRepaid: UFix64)
    access(all) event PositionRepaid(positionId: UInt64, borrower: Address, totalRepayment: UFix64)
    access(all) event LTVParametersUpdated(a: UFix64, b: UFix64, c: UFix64)
    access(all) event LTParametersUpdated(a: UFix64, b: UFix64, c: UFix64)
    access(all) event PriceCacheUpdated(symbol: String, price: UFix64, timestamp: UFix64)
    access(all) event HealthFactorUpdated(positionId: UInt64, oldHealthFactor: UFix64, newHealthFactor: UFix64)
    
    // Storage paths
    access(all) let AdminStoragePath: StoragePath
    access(all) let LendingManagerStoragePath: StoragePath
    access(all) let BorrowingManagerStoragePath: StoragePath
    access(all) let LiquidationManagerStoragePath: StoragePath

    // Price caching system
    access(all) var cachedPrices: {String: UFix64}  // symbol -> price in USD
    access(all) var lastPriceUpdate: {String: UFix64}  // symbol -> timestamp
    
    // Protocol parameters
    access(all) var maxLTV: UFix64  // Maximum Loan-to-Value ratio
    access(all) var maxLT: UFix64   // Maximum Liquidation Threshold
    access(all) var liquidationThreshold: UFix64  // Global liquidation threshold
    access(all) var baseInterestRate: UFix64  // Base interest rate (annual)
    
    // Dynamic LTV formula parameters: a + b*2^(c*t)
    access(all) var ltvFormulaA: UFix64
    access(all) var ltvFormulaB: UFix64
    access(all) var ltvFormulaC: Int64
    
    // Dynamic LT formula parameters: a + b*2^(c*t)
    access(all) var ltFormulaA: UFix64
    access(all) var ltFormulaB: UFix64
    access(all) var ltFormulaC: Int64

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
    
    // Borrowing position structure
    access(all) struct BorrowingPosition {
        access(all) let id: UInt64
        access(all) let borrower: Address
        access(all) let collateralType: Type
        access(all) var collateralAmount: UFix64  // Changed to var for partial liquidations
        access(all) let borrowTokenType: Type
        access(all) var borrowAmount: UFix64  // Changed to var for partial liquidations
        access(all) let durationMinutes: UInt64
        access(all) let calculatedLTV: UFix64
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
            self.repaymentDeadline = self.timestamp + UFix64(durationMinutes * 60)
            self.isActive = true
            self.healthFactor = healthFactor
            self.liquidationThreshold = liquidationThreshold
        }
        
        access(all) fun updateHealthFactor(newHealthFactor: UFix64) {
            self.healthFactor = newHealthFactor
        }
        
        access(all) fun updateAmounts(newCollateral: UFix64, newBorrow: UFix64) {
            self.collateralAmount = newCollateral
            self.borrowAmount = newBorrow
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
    
    // Protocol vaults
    access(all) var lendingVaults: @{Type: {FungibleToken.Vault}}
    access(all) var collateralVaults: @{Type: {FungibleToken.Vault}}
    
    // Position tracking
    access(all) var lendingPositions: {UInt64: LendingPosition}
    access(all) var borrowingPositions: {UInt64: BorrowingPosition}
    
    // Calculate dynamic LTV
    access(all) view fun calculateDynamicLTV(durationInMinutes: UInt64): UFix64 {
        let exponentValue = self.ltvFormulaC * Int64(durationInMinutes)
        var powerOfTwo: UFix64 = 0.0
        
        if exponentValue >= 0 {
            let shiftAmount = UInt64(exponentValue)
            if shiftAmount > 63 {
                powerOfTwo = UFix64(UInt64(1) << 63)
            } else {
                powerOfTwo = UFix64(UInt64(1) << shiftAmount)
            }
        } else {
            let positiveExponent = UInt64(-exponentValue)
            if positiveExponent > 63 {
                powerOfTwo = 0.0
            } else {
                let denominator = UFix64(UInt64(1) << positiveExponent)
                powerOfTwo = 1.0 / denominator
            }
        }
        
        let calculatedLTV = self.ltvFormulaA + self.ltvFormulaB * powerOfTwo
        
        if calculatedLTV > self.maxLTV {
            return self.maxLTV
        }
        if calculatedLTV < 0.0 {
            return 0.0
        }
        
        return calculatedLTV
    }

    // Calculate dynamic LT (Liquidation Threshold)
    access(all) view fun calculateDynamicLT(durationInMinutes: UInt64): UFix64 {
        let exponentValue = self.ltFormulaC * Int64(durationInMinutes)
        var powerOfTwo: UFix64 = 0.0
        
        if exponentValue >= 0 {
            let shiftAmount = UInt64(exponentValue)
            if shiftAmount > 63 {
                powerOfTwo = UFix64(UInt64(1) << 63)
            } else {
                powerOfTwo = UFix64(UInt64(1) << shiftAmount)
            }
        } else {
            let positiveExponent = UInt64(-exponentValue)
            if positiveExponent > 63 {
                powerOfTwo = 0.0
            } else {
                let denominator = UFix64(UInt64(1) << positiveExponent)
                powerOfTwo = 1.0 / denominator
            }
        }
        
        let calculatedLT = self.ltFormulaA + self.ltFormulaB * powerOfTwo
        
        if calculatedLT > self.maxLT {
            return self.maxLT
        }
        if calculatedLT < 0.0 {
            return 0.0
        }
        
        return calculatedLT
    }

    // Calculate health factor using cached prices
    access(all) view fun calculateHealthFactor(positionId: UInt64): UFix64 {
        let position = self.borrowingPositions[positionId] ?? panic("Position does not exist")
        
        // Get ETH price from cache (assuming collateral is always ETH)
        let ethPrice = self.cachedPrices["ETH"] ?? 2000.0
        
        // Calculate collateral value in USD
        let collateralValueUSD = position.collateralAmount * ethPrice
        
        // Assuming borrowed token is USD stablecoin (1:1 ratio)
        let debtValueUSD = position.borrowAmount * 1.0
        
        if debtValueUSD == 0.0 {
            return 999.9  // Very high health factor if no debt
        }
        
        // health_factor = (collateral_value * liquidation_threshold) / debt_value
        let healthFactor = (collateralValueUSD * position.liquidationThreshold) / debtValueUSD
        
        return healthFactor
    }

    // Soft Liquidation - Partial liquidation when health factor < 1.0
    access(all) fun softLiquidatePosition(
        positionId: UInt64,
        liquidator: Address,
        repaymentVault: @{FungibleToken.Vault},
        liquidatorRecipient: &{FungibleToken.Receiver}
    ) {
        pre {
            self.borrowingPositions[positionId] != nil: "Position does not exist"
            self.borrowingPositions[positionId]!.isActive: "Position is not active"
            self.borrowingPositions[positionId]!.healthFactor < 1.0: "Position is healthy, health factor must be < 1.0"
        }
        
        let position = self.borrowingPositions[positionId]!
        
        // Get current prices
        let ethPrice = self.cachedPrices["ETH"] ?? 2000.0
        let usdPrice: UFix64 = 1.0
        
        // Calculate current collateral value in USD
        let collateralValueUSD = position.collateralAmount * ethPrice
        
        // Target health factor of 1.1
        let targetHealthFactor: UFix64 = 1.1
        
        // Calculate target debt: HF = (collateral * LT) / debt
        // target_debt = (collateral * LT) / target_HF
        let targetDebtUSD = (collateralValueUSD * position.liquidationThreshold) / targetHealthFactor
        
        // Current debt in USD
        let currentDebtUSD = position.borrowAmount * usdPrice
        
        // Amount of debt to be repaid
        let debtToRepayUSD = currentDebtUSD - targetDebtUSD
        
        // Ensure we have something to liquidate
        if debtToRepayUSD <= 0.0 {
            destroy repaymentVault
            panic("No liquidation needed, position already healthy enough")
        }
        
        // Check repayment vault has enough
        if repaymentVault.balance < debtToRepayUSD {
            let balance = repaymentVault.balance
            destroy repaymentVault
            panic("Insufficient repayment. Required: ".concat(debtToRepayUSD.toString()).concat(", Provided: ").concat(balance.toString()))
        }
        
        // Calculate collateral to give to liquidator (with 5% bonus)
        let liquidationBonus: UFix64 = 1.05
        let collateralValueToLiquidateUSD = debtToRepayUSD * liquidationBonus
        let collateralToLiquidate = collateralValueToLiquidateUSD / ethPrice
        
        // Ensure we don't try to withdraw more collateral than available
        if collateralToLiquidate > position.collateralAmount {
            destroy repaymentVault
            panic("Calculated collateral exceeds available collateral")
        }
        
        // Deposit repayment into lending vault
        if self.lendingVaults[position.borrowTokenType] != nil {
            let vaultRef = (&self.lendingVaults[position.borrowTokenType] as &{FungibleToken.Vault}?)!
            let exactRepayment <- repaymentVault.withdraw(amount: debtToRepayUSD)
            vaultRef.deposit(from: <-exactRepayment)
        } else {
            let exactRepayment <- repaymentVault.withdraw(amount: debtToRepayUSD)
            self.lendingVaults[position.borrowTokenType] <-! exactRepayment
        }
        
        // Return excess repayment to liquidator if any
        if repaymentVault.balance > 0.0 {
            liquidatorRecipient.deposit(from: <-repaymentVault)
        } else {
            destroy repaymentVault
        }
        
        // Transfer collateral to liquidator
        if let collateralVaultRef = &self.collateralVaults[position.collateralType] as auth(FungibleToken.Withdraw) &{FungibleToken.Vault}? {
            let collateral <- collateralVaultRef.withdraw(amount: collateralToLiquidate)
            liquidatorRecipient.deposit(from: <-collateral)
        }
        
        // Update position with new amounts
        let newCollateralAmount = position.collateralAmount - collateralToLiquidate
        let newBorrowAmount = position.borrowAmount - debtToRepayUSD
        
        // Update the position in storage
        self.borrowingPositions[positionId]!.updateAmounts(newCollateral: newCollateralAmount, newBorrow: newBorrowAmount)
        
        // Recalculate and update health factor
        let newHealthFactor = self.calculateHealthFactor(positionId: positionId)
        self.borrowingPositions[positionId]!.updateHealthFactor(newHealthFactor: newHealthFactor)
        
        emit PositionLiquidated(
            positionId: positionId, 
            liquidator: liquidator, 
            liquidationType: "SoftLiquidation",
            collateralLiquidated: collateralToLiquidate,
            debtRepaid: debtToRepayUSD
        )
    }

    // Hard Liquidation - Full liquidation for overdue positions
    access(all) fun hardLiquidateOverduePosition(
        positionId: UInt64,
        liquidator: Address,
        repaymentVault: @{FungibleToken.Vault},
        liquidatorRecipient: &{FungibleToken.Receiver}
    ) {
        pre {
            self.borrowingPositions[positionId] != nil: "Position does not exist"
            self.borrowingPositions[positionId]!.isActive: "Position is not active"
            self.borrowingPositions[positionId]!.isOverdue(): "Position is not overdue yet"
        }
        
        let position = self.borrowingPositions[positionId]!
        
        // Calculate total debt including interest
        let timeElapsed = getCurrentBlock().timestamp - position.timestamp
        let annualRate = self.baseInterestRate
        let interest = position.borrowAmount * annualRate * timeElapsed / 31536000.0
        let totalDebt = position.borrowAmount + interest
        
        // Liquidator must repay the full debt
        if repaymentVault.balance < totalDebt {
            let balance = repaymentVault.balance
            destroy repaymentVault
            panic("Insufficient repayment for full liquidation. Required: ".concat(totalDebt.toString()).concat(", Provided: ").concat(balance.toString()))
        }
        
        // Deposit full repayment into lending vault
        if self.lendingVaults[position.borrowTokenType] != nil {
            let vaultRef = (&self.lendingVaults[position.borrowTokenType] as &{FungibleToken.Vault}?)!
            let exactRepayment <- repaymentVault.withdraw(amount: totalDebt)
            vaultRef.deposit(from: <-exactRepayment)
        } else {
            let exactRepayment <- repaymentVault.withdraw(amount: totalDebt)
            self.lendingVaults[position.borrowTokenType] <-! exactRepayment
        }
        
        // Return excess repayment to liquidator if any
        if repaymentVault.balance > 0.0 {
            liquidatorRecipient.deposit(from: <-repaymentVault)
        } else {
            destroy repaymentVault
        }
        
        // Transfer ALL collateral to liquidator
        if let collateralVaultRef = &self.collateralVaults[position.collateralType] as auth(FungibleToken.Withdraw) &{FungibleToken.Vault}? {
            let collateral <- collateralVaultRef.withdraw(amount: position.collateralAmount)
            liquidatorRecipient.deposit(from: <-collateral)
        }
        
        // Close position completely
        self.borrowingPositions[positionId]!.close()
        
        emit PositionLiquidated(
            positionId: positionId, 
            liquidator: liquidator, 
            liquidationType: "HardLiquidation",
            collateralLiquidated: position.collateralAmount,
            debtRepaid: totalDebt
        )
    }

    // Admin resource
    access(all) resource Admin {
        
        access(all) fun updateLTV(newLTV: UFix64) {
            pre {
                newLTV <= 1.0: "LTV cannot exceed 100%"
            }
            TimeLendingProtocol.maxLTV = newLTV
        }
        
        access(all) fun updateMaxLT(newMaxLT: UFix64) {
            pre {
                newMaxLT <= 1.0: "LT cannot exceed 100%"
            }
            TimeLendingProtocol.maxLT = newMaxLT
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
        
        access(all) fun updateLTFormulaParameters(a: UFix64, b: UFix64, c: Int64) {
            TimeLendingProtocol.ltFormulaA = a
            TimeLendingProtocol.ltFormulaB = b
            TimeLendingProtocol.ltFormulaC = c
            
            emit LTParametersUpdated(a: a, b: b, c: UFix64(c))
        }
        
        access(all) fun addSupportedToken(tokenType: Type, vault: @{FungibleToken.Vault}) {
            TimeLendingProtocol.lendingVaults[tokenType] <-! vault
        }

        access(all) fun createMinter(tokenType: Type): @{IWrappedToken.Minter}? {
            return nil
        }
        
        access(all) fun createBurner(tokenType: Type): @{IWrappedToken.Burner}? {
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
            
            if TimeLendingProtocol.lendingVaults[tokenType] != nil {
                let vaultRef = (&TimeLendingProtocol.lendingVaults[tokenType] as &{FungibleToken.Vault}?)!
                vaultRef.deposit(from: <-tokenVault)
            } else {
                TimeLendingProtocol.lendingVaults[tokenType] <-! tokenVault
            }
            
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
        
        access(all) fun withdrawLending(positionId: UInt64, recipient: &{FungibleToken.Receiver}) {
            pre {
                TimeLendingProtocol.lendingPositions[positionId] != nil: "Position does not exist"
                TimeLendingProtocol.lendingPositions[positionId]!.isActive: "Position is not active"
            }
            
            let position = TimeLendingProtocol.lendingPositions[positionId]!
            let tokenType = position.tokenType
            
            if let vaultRef = &TimeLendingProtocol.lendingVaults[tokenType] as auth(FungibleToken.Withdraw) &{FungibleToken.Vault}? {
                let withdrawnTokens <- vaultRef.withdraw(amount: position.amount)
                recipient.deposit(from: <-withdrawnTokens)
                
                TimeLendingProtocol.lendingPositions[positionId]!.deactivate()
            }
        }
    }
    
    // Borrowing Manager resource
    access(all) resource BorrowingManager {
        
        access(all) fun createBorrowingPosition(
            collateralVault: @{FungibleToken.Vault},
            borrowTokenType: Type,
            borrowAmount: UFix64,
            durationMinutes: UInt64,
            borrower: Address
        ): UInt64? {
            let positionId = TimeLendingProtocol.nextBorrowingPositionId
            TimeLendingProtocol.nextBorrowingPositionId = positionId + 1
            
            let collateralType = collateralVault.getType()
            let collateralAmount = collateralVault.balance
            
            // Calculate dynamic LTV and LT
            let calculatedLTV = TimeLendingProtocol.calculateDynamicLTV(durationInMinutes: durationMinutes)
            let liquidationThreshold = TimeLendingProtocol.calculateDynamicLT(durationInMinutes: durationMinutes)
            
            // Get current ETH price
            let ethPrice = TimeLendingProtocol.cachedPrices["ETH"] ?? 2000.0
            
            // Calculate max borrow amount in USD
            let collateralValueUSD = collateralAmount * ethPrice
            let maxBorrowAmount = collateralValueUSD * calculatedLTV
            
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
            
            // Calculate initial health factor
            let initialHealthFactor = (collateralValueUSD * liquidationThreshold) / borrowAmount
            
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
                liquidationThreshold: liquidationThreshold,
                healthFactor: initialHealthFactor
            )
            
            TimeLendingProtocol.borrowingPositions[positionId] = position
            
            emit BorrowingPositionCreated(
                borrower: borrower,
                collateralAmount: collateralAmount,
                borrowAmount: borrowAmount,
                positionId: positionId,
                durationMinutes: durationMinutes,
                calculatedLTV: calculatedLTV,
                liquidationThreshold: liquidationThreshold,
                healthFactor: initialHealthFactor
            )
            
            return positionId
        }
        
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
            
            // Calculate interest
            let timeElapsed = getCurrentBlock().timestamp - position.timestamp
            let annualRate = TimeLendingProtocol.baseInterestRate
            let interest = position.borrowAmount * annualRate * timeElapsed / 31536000.0
            let totalRepayment = position.borrowAmount + interest
            
            if repaymentVault.balance < totalRepayment {
                let repaymentBalance = repaymentVault.balance
                destroy repaymentVault
                panic("Insufficient repayment amount. Required: ".concat(totalRepayment.toString()).concat(", Provided: ").concat(repaymentBalance.toString()))
            }
            
            // Deposit repayment
            if TimeLendingProtocol.lendingVaults[position.borrowTokenType] != nil {
                let vaultRef = (&TimeLendingProtocol.lendingVaults[position.borrowTokenType] as &{FungibleToken.Vault}?)!
                
                if repaymentVault.balance > totalRepayment {
                    let exactRepayment <- repaymentVault.withdraw(amount: totalRepayment)
                    vaultRef.deposit(from: <-exactRepayment)
                    destroy repaymentVault
                } else {
                    vaultRef.deposit(from: <-repaymentVault)
                }
            } else {
                TimeLendingProtocol.lendingVaults[position.borrowTokenType] <-! repaymentVault
            }
            
            // Return collateral
            if let collateralVaultRef = &TimeLendingProtocol.collateralVaults[position.collateralType] as auth(FungibleToken.Withdraw) &{FungibleToken.Vault}? {
                let collateral <- collateralVaultRef.withdraw(amount: position.collateralAmount)
                collateralRecipient.deposit(from: <-collateral)
            }
            
            // Close position
            TimeLendingProtocol.borrowingPositions[positionId]!.close()
            
            emit PositionRepaid(positionId: positionId, borrower: position.borrower, totalRepayment: totalRepayment)
        }
    }
    
    // Liquidation Manager resource
    access(all) resource LiquidationManager {
        
        access(all) fun updateHealthFactors(positionIds: [UInt64]) {
            for positionId in positionIds {
                if let position = TimeLendingProtocol.borrowingPositions[positionId] {
                    if position.isActive {
                        let oldHealthFactor = position.healthFactor
                        let newHealthFactor = TimeLendingProtocol.calculateHealthFactor(positionId: positionId)
                        
                        TimeLendingProtocol.borrowingPositions[positionId]!.updateHealthFactor(newHealthFactor: newHealthFactor)
                        
                        emit HealthFactorUpdated(
                            positionId: positionId,
                            oldHealthFactor: oldHealthFactor,
                            newHealthFactor: newHealthFactor
                        )
                    }
                }
            }
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
            "maxLT": self.maxLT,
            "liquidationThreshold": self.liquidationThreshold,
            "baseInterestRate": self.baseInterestRate,
            "ltvFormulaA": self.ltvFormulaA,
            "ltvFormulaB": self.ltvFormulaB,
            "ltvFormulaC": self.ltvFormulaC,
            "ltFormulaA": self.ltFormulaA,
            "ltFormulaB": self.ltFormulaB,
            "ltFormulaC": self.ltFormulaC
        }
    }
    
    access(all) fun getCachedPrice(symbol: String): UFix64? {
        return self.cachedPrices[symbol]
    }
    
    access(all) fun getLastPriceUpdate(symbol: String): UFix64? {
        return self.lastPriceUpdate[symbol]
    }
    
    access(all) view fun previewDynamicLTV(durationInMinutes: UInt64): UFix64 {
        return self.calculateDynamicLTV(durationInMinutes: durationInMinutes)
    }
    
    access(all) view fun previewDynamicLT(durationInMinutes: UInt64): UFix64 {
        return self.calculateDynamicLT(durationInMinutes: durationInMinutes)
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
    
    access(all) fun getUnhealthyPositions(): [UInt64] {
        let unhealthyPositions: [UInt64] = []
        for positionId in self.borrowingPositions.keys {
            if let position = self.borrowingPositions[positionId] {
                if position.isActive && position.healthFactor < 1.0 {
                    unhealthyPositions.append(positionId)
                }
            }
        }
        return unhealthyPositions
    }

    // Update cached price from Oracle
    access(all) fun updateCachedPrice(symbol: String, payment: @{FungibleToken.Vault}) {
        let priceStr = Oracle.getPrice(symbol: symbol, payment: <- payment)
        let price = UFix64.fromString(priceStr) ?? 0.0
        
        self.cachedPrices[symbol] = price
        self.lastPriceUpdate[symbol] = getCurrentBlock().timestamp
        
        emit PriceCacheUpdated(symbol: symbol, price: price, timestamp: getCurrentBlock().timestamp)
    }
    
    init() {
        // Initialize storage paths
        self.AdminStoragePath = /storage/TimeLendingAdmin
        self.LendingManagerStoragePath = /storage/TimeLendingManager
        self.BorrowingManagerStoragePath = /storage/TimeBorrowingManager
        self.LiquidationManagerStoragePath = /storage/TimeLiquidationManager

        // Initialize cached prices with zero (will be updated via Oracle)
        self.cachedPrices = {
            "ETH": 0.0,
            "FLOW": 0.0,
            "USDC": 1.0,  // Stablecoin defaults to 1.0
            "USDT": 1.0   // Stablecoin defaults to 1.0
        }
        
        // Initialize last price update timestamps
        self.lastPriceUpdate = {
            "ETH": getCurrentBlock().timestamp,
            "FLOW": getCurrentBlock().timestamp,
            "USDC": getCurrentBlock().timestamp,
            "USDT": getCurrentBlock().timestamp
        }

        // Initialize protocol parameters
        self.maxLTV = 0.75  // 75%
        self.maxLT = 0.90   // 90%
        self.liquidationThreshold = 0.85  // 85%
        self.baseInterestRate = 0.05  // 5% per year
        
        // Initialize LTV formula parameters
        // Formula: 0.3 + 0.4*2^(-1*t) gives higher LTV for shorter durations
        // With t in minutes: 1 min -> LTV≈0.5, 2 min -> LTV≈0.4, 3 min -> LTV≈0.35
        self.ltvFormulaA = 0.30  // Base LTV (30%)
        self.ltvFormulaB = 0.40  // Exponential coefficient (40%)
        self.ltvFormulaC = -1    // Negative time multiplier (decay)
        
        // Initialize LT formula parameters
        // Formula: 0.35 + 0.45*2^(-1*t) gives higher LT for shorter durations
        self.ltFormulaA = 0.35  // Base LT (35%)
        self.ltFormulaB = 0.45  // Exponential coefficient (45%)
        self.ltFormulaC = -1    // Negative time multiplier (decay)

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