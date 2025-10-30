import FungibleToken from 0x9a0766d93b6608b7
import FlowToken from 0x7e60df042a9c0868
import LiquidationPool from 0xe11cab85e85ae137
import BandOracle from 0x9fb6606c300b5051

/// Transaction to execute hard liquidation on an overdue position
/// @param positionId: The ID of the overdue position to liquidate
/// @param debtTokenType: Either "FLOW" or "USDC" - the token type used for debt repayment
/// @param oraclePaymentAmount: Amount of Flow tokens to pay for oracle price feed
transaction(positionId: UInt64, debtTokenType: String) {
    
    let poolAdmin: &LiquidationPool.PoolAdmin
    let oraclePayment: @FlowToken.Vault
    let signerAddress: Address
    
    prepare(signer: auth(BorrowValue) &Account) {
        self.signerAddress = signer.address
        
        // Withdraw Flow for oracle payment
        let flowVaultRef = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
            from: /storage/flowTokenVault
        ) ?? panic("Could not borrow Flow vault reference")

        self.oraclePayment <- flowVaultRef.withdraw(amount: BandOracle.getFee()) as! @FlowToken.Vault

        // Borrow PoolAdmin capability
        self.poolAdmin = signer.storage.borrow<&LiquidationPool.PoolAdmin>(
            from: LiquidationPool.PoolAdminStoragePath
        ) ?? panic("Could not borrow PoolAdmin reference. Make sure you have admin privileges.")
    }
    
    execute {
        // Execute hard liquidation
        self.poolAdmin.executeHardLiquidation(
            positionId: positionId,
            liquidatorAddress: self.signerAddress,
            debtTokenType: debtTokenType,
            oraclePayment: <-self.oraclePayment
        )
        
        log("Successfully executed hard liquidation for position: ".concat(positionId.toString()))
        log("Liquidator: ".concat(self.signerAddress.toString()))
        log("Debt token used: ".concat(debtTokenType))
    }
    
    post {
        // Verify the liquidation was successful
        true: "Hard liquidation completed"
    }
}