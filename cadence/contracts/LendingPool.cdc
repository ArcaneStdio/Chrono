import "FungibleToken"
import "CollateralVault"
import "Oracle"

/// The main contract for the lending protocol.
///
/// This contract manages multiple lending pools, allowing users to lend assets
/// to earn interest and borrow assets against their collateral.
///
access(all) contract LendingPool {

    // --- Events ---
    access(all) event Lent(lender: Address, tokenType: Type, amount: UFix64)
    access(all) event Borrowed(borrower: Address, tokenType: Type, amount: UFix64)
    access(all) event Repaid(borrower: Address, tokenType: Type, amount: UFix64)

    // --- Contract State ---

    /// A dictionary of all the token pools, mapping a token Type to its Vault.
    access(all) let pools: @{Type: FungibleToken.Vault}

    /// A nested dictionary to track the borrowed amounts.
    /// {Borrower_Address: {Borrowed_Token_Type: Amount}}
    access(self) var borrowedAmounts: {Address: {Type: UFix64}}

    /// A reference to the price oracle contract to get asset prices.
    access(all) let oracle: &{Oracle.PriceOracle}

    /// The Loan-to-Value ratio, representing the maximum percentage of
    /// collateral value that can be borrowed. 75% LTV.
    access(all) let loanToValueRatio: UFix64

    // --- Core Functions ---

    /**
        Lends tokens to a pool. The lender provides a vault of tokens,
        which is deposited into the corresponding pool.
    */
    access(all) fun lend(from: @FungibleToken.Vault) {
        let tokenType = from.getType()
        let amount = from.balance
        let lender = from.owner?.address ?? panic("Lender address not found")

        // Get the pool for the token type, or create a new one if it doesn't exist.
        if var vault <- self.pools.remove(key: tokenType) {
            vault.deposit(from: <-from)
            self.pools[tokenType] <-! vault
        } else {
            self.pools[tokenType] <-! from
        }

        emit Lent(lender: lender, tokenType: tokenType, amount: amount)
    }

    /**
        Borrows tokens from a pool. The borrower must provide sufficient collateral.
        The function calculates the borrow limit based on the collateral's value and the LTV ratio.
        Returns a vault containing the borrowed tokens.
    */
    access(all) fun borrow(borrower: Address, collateralVault: &CollateralVault.Vault, borrowAmount: UFix64, borrowTokenType: Type): @FungibleToken.Vault {
        // Calculate the value of the provided collateral.
        let collateralValue = self.oracle.getPrice(collateralVault.tokenType) * collateralVault.balance
        let borrowLimit = collateralValue * self.loanToValueRatio

        // Calculate the value of the amount to be borrowed.
        let borrowValue = self.oracle.getPrice(borrowTokenType) * borrowAmount

        assert(borrowValue <= borrowLimit, message: "Borrow amount exceeds the allowed LTV")

        // Withdraw the requested amount from the correct pool.
        let poolVault <- self.pools.remove(key: borrowTokenType) ?? panic("No pool for the requested token type")
        let borrowedVault <- poolVault.withdraw(amount: borrowAmount)
        self.pools[borrowTokenType] <-! poolVault // Return the pool vault

        // --- Correctly update the nested borrowedAmounts dictionary ---
        // Get a mutable reference to the borrower's debt map.
        var borrowerDebts: {Type: UFix64} = self.borrowedAmounts[borrower]!
            // ============== Note: changed borrower debts dtype from  Ufix64? to Ufix64 so that the borrowerDebts[borrowTokenType] line doesn't throw err 
            // Look into the errors possible when it is null etc and perform graceful handling.
        if borrowerDebts == nil {
            // If the borrower has no previous debts, create a new record.
            self.borrowedAmounts[borrower] = {borrowTokenType: borrowAmount}
        } else {
            // If the borrower already has debts, update the specific token debt.
            let currentDebt = borrowerDebts[borrowTokenType] ?? 0.0
            borrowerDebts[borrowTokenType] = currentDebt + borrowAmount
            self.borrowedAmounts[borrower] = borrowerDebts
        }
        
        emit Borrowed(borrower: borrower, tokenType: borrowTokenType, amount: borrowAmount)

        return <-borrowedVault
    }

    /**
        Repays a loan. The borrower provides a vault of tokens which is
        deposited back into the corresponding pool, and their debt is cleared.
    */
    access(all) fun repay(borrower: Address, repaymentVault: @FungibleToken.Vault) {
        let tokenType = repaymentVault.getType()
        let repaymentAmount = repaymentVault.balance

        // Ensure the borrower has an outstanding debt for this token type.
        let borrowedAmount = self.borrowedAmounts[borrower]![tokenType] ?? 0.00
        assert(borrowedAmount > 0.0, message: "No outstanding debt for this token")
        assert(repaymentAmount >= borrowedAmount, message: "Repayment amount is less than the borrowed amount")

        // Deposit the repayment back into the pool.
        let poolVault <- self.pools.remove(key: tokenType) ?? panic("Pool does not exist")
        poolVault.deposit(from: <-repaymentVault)
        self.pools[tokenType] <-! poolVault

        // Clear the borrower's debt for this token.
        self.borrowedAmounts[borrower]!.remove(key: tokenType)

        emit Repaid(borrower: borrower, tokenType: tokenType, amount: repaymentAmount)
    }

    init(oracle: &{Oracle.PriceOracle}) {
        self.pools <- {}
        self.borrowedAmounts = {}
        self.oracle = oracle
        self.loanToValueRatio = 0.75
    }
}