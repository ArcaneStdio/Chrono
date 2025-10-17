/// An interface for a price oracle.
///
access(all) contract Oracle {

    /// The interface for the price oracle
    access(all) resource interface PriceOracle {
        /// Get the price of a token
        access(all) view fun getPrice(_ token: Type): UFix64
    }
}