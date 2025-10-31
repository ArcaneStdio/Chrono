import LiquidationPoolTransactionHandler from 0xe11cab85e85ae137
import FlowTransactionScheduler from 0x8c5303eaa26202d6

transaction() {
    prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, SaveValue, PublishCapability) &Account) {
        // Save a handler resource to storage if not already present
        if signer.storage.borrow<&AnyResource>(from: /storage/LiquidationPoolTransactionHandler) == nil {
            let handler <- LiquidationPoolTransactionHandler.createHandler()
            signer.storage.save(<-handler, to: /storage/LiquidationPoolTransactionHandler)
        }

        // Validation/example that we can create an issue a handler capability with correct entitlement for FlowTransactionScheduler
        let _ = signer.capabilities.storage
            .issue<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>(/storage/LiquidationPoolTransactionHandler)
    
        // Issue a non-entitled public capability for the handler that is publicly accessible
        let publicCap = signer.capabilities.storage
            .issue<&{FlowTransactionScheduler.TransactionHandler}>(/storage/LiquidationPoolTransactionHandler)
        // publish the capability
        signer.capabilities.publish(publicCap, at: /public/LiquidationPoolTransactionHandler)
    }
}