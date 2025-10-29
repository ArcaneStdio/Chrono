import FungibleToken from 0x9a0766d93b6608b7
import TimeLendingProtocol2 from 0xe11cab85e85ae137
import WrappedETH1 from 0xe11cab85e85ae137
import WrappedUSDC1 from 0xe11cab85e85ae137
import FlowToken from 0x7e60df042a9c0868

// Transaction to withdraw tokens from a lending position
// This returns your deposited tokens plus any earned interest back to your wallet

transaction(positionId: UInt64) {
    
    let lendingManagerRef: &TimeLendingProtocol2.LendingManager
    let recipient: &{FungibleToken.Receiver}
    let position: TimeLendingProtocol2.LendingPosition
    
    prepare(signer: auth(BorrowValue, Storage, Capabilities) &Account) {
        // Get the lending position to check details
        self.position = TimeLendingProtocol2.getLendingPosition(id: positionId)
            ?? panic("Lending position does not exist")
        
        // Verify the signer is the lender
        if self.position.lender != signer.address {
            panic("Only the lender can withdraw this position")
        }
        
        if !self.position.isActive {
            panic("Position is not active - already withdrawn")
        }
        
        // Get reference to the lending manager
        self.lendingManagerRef = TimeLendingProtocol2.borrowLendingManager()
        
        // Determine which token type was lent
        let tokenType = self.position.tokenType
        
        log("Lending Position Details:")
        log("  Position ID: ".concat(positionId.toString()))
        log("  Lender: ".concat(self.position.lender.toString()))
        log("  Amount: ".concat(self.position.amount.toString()))
        log("  Token Type: ".concat(tokenType.identifier))
        log("  Timestamp: ".concat(self.position.timestamp.toString()))
        
        // Setup recipient based on token type
        // if tokenType == Type<@WrappedETH1.Vault>() {
        //     // Receiving ETH back
        //     self.recipient = signer.capabilities.get<&{FungibleToken.Receiver}>(
        //         WrappedETH1.ReceiverPublicPath
        //     ).borrow() ?? panic("Could not borrow WrappedETH receiver capability. Make sure you have WrappedETH1 vault set up.")
            
        //     log("  Withdrawing to: WrappedETH vault")
            
        // } else if tokenType == Type<@WrappedUSDC1.Vault>() {
            // Receiving USDC back
            self.recipient = signer.capabilities.get<&{FungibleToken.Receiver}>(
                WrappedUSDC1.ReceiverPublicPath
            ).borrow() ?? panic("Could not borrow WrappedUSDC receiver capability. Make sure you have WrappedUSDC1 vault set up.")
            
            log("  Withdrawing to: WrappedUSDC vault")
            
        // } else if tokenType == Type<@FlowToken.Vault>() {
        //     // Receiving FLOW back
        //     self.recipient = signer.capabilities.get<&{FungibleToken.Receiver}>(
        //         /public/flowTokenReceiver
        //     ).borrow() ?? panic("Could not borrow FLOW receiver capability")
            
        //     log("  Withdrawing to: FLOW vault")
            
        // } else {
        //     panic("Unsupported token type: ".concat(tokenType.identifier))
        // }
        
        // Calculate time elapsed
        let timeElapsed = getCurrentBlock().timestamp - self.position.timestamp
        let daysElapsed = timeElapsed / 86400.0
        log("  Time Elapsed: ".concat(daysElapsed.toString()).concat(" days"))
    }
    
    execute {
        // Withdraw the lending position
        self.lendingManagerRef.withdrawLending(
            positionId: positionId,
            recipient: self.recipient
        )
        
        log("")
        log("✅ Successfully withdrawn lending position!")
        log("  Amount Withdrawn: ".concat(self.position.amount.toString()))
        log("  Position Closed: #".concat(positionId.toString()))
        log("  Tokens returned to your wallet")
    }
}