import "FungibleToken"
import "Oracle"

/// The main contract for the lending protocol.
///
access(all) contract LendingPool {

    // A map of token types to their corresponding lending vaults
    access(all) let pools: {Type: @FungibleToken.Vault}

    // A map of users to their borrowed amounts
    access(self) let borrowedAmounts: {Address: {Type: UFix64}}

    // A reference to the Oracle contract for price feeds
    access(all) let oracle: &Oracle.PriceOracle

    /// Lend tokens to the pool
    access(all) fun lend(from: @FungibleToken.Vault) {
        let tokenType = from.getType()
        if self.pools[tokenType] == nil {
            self.pools[tokenType] <-! from
        } else {
            let poolVault = self.pools[tokenType]!
            poolVault.deposit(from: <-from)
            self.pools[tokenType] <-! poolVault
        }
    }

    /// Borrow tokens from the pool
    access(all) fun borrow(borrower: Address, collateralVault: &CollateralVault.Vault, borrowAmount: UFix64, borrowTokenType: Type) {
        let collateralValue = self.oracle.getPrice(collateralVault.tokenType) * collateralVault.balance
        let ltv = 0.75 // 75% LTV, this should be configurable
        let borrowLimit = collateralValue * ltv
        let borrowValue = self.oracle.getPrice(borrowTokenType) * borrowAmount

        assert(borrowValue <= borrowLimit, message: "Borrow amount exceeds LTV")

        let poolVault = self.pools[borrowTokenType] ?? panic("No pool for the requested token")
        let borrowedVault <- poolVault.withdraw(amount: borrowAmount)

        // Transfer the borrowed tokens to the borrower
        // (This is a simplified example, in a real scenario you would use a receiver capability)

        // Update the borrowed amounts
        if self.borrowedAmounts[borrower] == nil {
            self.borrowedAmounts[borrower] = {}
        }
        self.borrowedAmounts[borrower]![borrowTokenType] = (self.borrowedAmounts[borrower]![borrowTokenType] ?? 0.0) + borrowAmount
    }

    /// Repay a loan
    access(all) fun repay(borrower: Address, repaymentVault: @FungibleToken.Vault) {
        let tokenType = repaymentVault.getType()
        let borrowedAmount = self.borrowedAmounts[borrower]?[tokenType] ?? 0.0
        assert(repaymentVault.balance >= borrowedAmount, message: "Repayment amount is less than the borrowed amount")

        let poolVault = self.pools[tokenType]!
        poolVault.deposit(from: <-repaymentVault)
        self.pools[tokenType] <-! poolVault

        self.borrowedAmounts[borrower]![tokenType] = 0.0
    }

    init(oracle: &Oracle.PriceOracle) {
        self.pools = {}
        self.borrowedAmounts = {}
        self.oracle = oracle
    }
}