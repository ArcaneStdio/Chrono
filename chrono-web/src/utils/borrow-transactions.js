import * as fcl from '@onflow/fcl'
import * as t from '@onflow/types'
import { executeTransaction } from './flowWallet'

// Borrow USDC using WETH collateral (same as borrow-transaction-eth.js cadence)
const BORROW_USDC_TX = `
import FungibleToken from 0x9a0766d93b6608b7
import FlowToken from 0x7e60df042a9c0868
import TimeLendingProtocol2 from 0xe11cab85e85ae137
import WrappedETH1 from 0xe11cab85e85ae137
import WrappedUSDC1 from 0xe11cab85e85ae137
import BandOracle from 0x9fb6606c300b5051

transaction(
    collateralAmount: UFix64,
    borrowAmount: UFix64,
    durationMinutes: UInt64
) {
    let borrowingManagerRef: &TimeLendingProtocol2.BorrowingManager
    let collateralVault: @{FungibleToken.Vault}
    let borrowedTokensReceiver: &{FungibleToken.Receiver}
    let oraclePayment1: @{FungibleToken.Vault}
    let oraclePayment2: @{FungibleToken.Vault}
    let signerAddress: Address
    
    prepare(signer: auth(BorrowValue, Storage, Capabilities) &Account) {
        self.signerAddress = signer.address
        self.borrowingManagerRef = TimeLendingProtocol2.borrowBorrowingManager()
        let wrappedETHVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &{FungibleToken.Vault}>(
            from: WrappedETH1.VaultStoragePath
        ) ?? panic("Could not borrow Wrapped ETH vault from storage. Make sure you have WrappedETH1 vault set up.")
        self.collateralVault <- wrappedETHVault.withdraw(amount: collateralAmount)
        self.borrowedTokensReceiver = signer.capabilities.get<&{FungibleToken.Receiver}>(
            WrappedUSDC1.ReceiverPublicPath
        ).borrow() ?? panic("Could not borrow USDC receiver capability. Make sure you have WrappedUSDC1 vault set up.")
        let flowVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
            from: /storage/flowTokenVault
        ) ?? panic("Could not borrow FLOW vault from storage")
        self.oraclePayment1 <- flowVault.withdraw(amount: BandOracle.getFee())
        self.oraclePayment2 <- flowVault.withdraw(amount: BandOracle.getFee())
    }
    
    execute {
        let positionId = self.borrowingManagerRef.createBorrowingPosition(
            collateralVault: <- self.collateralVault,
            borrowTokenType: Type<@WrappedUSDC1.Vault>(),
            borrowAmount: borrowAmount,
            durationMinutes: durationMinutes,
            borrower: self.signerAddress,
            borrowerRecipient: self.borrowedTokensReceiver,
            oraclePayment1: <- self.oraclePayment1,
            oraclePayment2: <- self.oraclePayment2
        )
        if positionId == nil { panic("Failed to create borrowing position - borrow amount exceeds LTV limit") }
    }
}`

// Borrow WETH using USDC as the borrowed token indicated in borowEth.cdc (as provided)
const BORROW_WETH_TX = `
import FungibleToken from 0x9a0766d93b6608b7
import FlowToken from 0x7e60df042a9c0868
import TimeLendingProtocol2 from 0xe11cab85e85ae137
import WrappedETH1 from 0xe11cab85e85ae137
import WrappedUSDC1 from 0xe11cab85e85ae137
import BandOracle from 0x9fb6606c300b5051

// Transaction to borrow USDC using Wrapped ETH as collateral
transaction(
    collateralAmount: UFix64,      // Amount of Wrapped ETH to use as collateral
    borrowAmount: UFix64,           // Amount of USDC to borrow
    durationMinutes: UInt64         // Duration of the loan in minutes
) {
    
    let borrowingManagerRef: &TimeLendingProtocol2.BorrowingManager
    let collateralVault: @{FungibleToken.Vault}
    let borrowedTokensReceiver: &{FungibleToken.Receiver}
    let oraclePayment1: @{FungibleToken.Vault}
    let oraclePayment2: @{FungibleToken.Vault}
    let signerAddress: Address
    
    prepare(signer: auth(BorrowValue, Storage, Capabilities) &Account) {
        self.signerAddress = signer.address
        
        // Get reference to the borrowing manager
        self.borrowingManagerRef = TimeLendingProtocol2.borrowBorrowingManager()
        
        // Withdraw Wrapped ETH collateral from signer's vault using WrappedETH1 paths
        let wrappedUSDCVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &{FungibleToken.Vault}>(
            from: WrappedUSDC1.VaultStoragePath
        ) ?? panic("Could not borrow Wrapped ETH vault from storage. Make sure you have WrappedETH1 vault set up.")
        
        self.collateralVault <- wrappedETHVault.withdraw(amount: collateralAmount)
        
        // Get receiver capability for borrowed USDC tokens using WrappedUSDC1 paths
        self.borrowedTokensReceiver = signer.capabilities.get<&{FungibleToken.Receiver}>(
            WrappedETH1.ReceiverPublicPath
        ).borrow() ?? panic("Could not borrow USDC receiver capability. Make sure you have WrappedUSDC1 vault set up.")
        
        // Withdraw FLOW tokens for oracle payment using BandOracle fee
        let flowVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
            from: /storage/flowTokenVault
        ) ?? panic("Could not borrow FLOW vault from storage")
        
        self.oraclePayment1 <- flowVault.withdraw(amount: BandOracle.getFee())
        self.oraclePayment2 <- flowVault.withdraw(amount: BandOracle.getFee())
    }
    
    execute {
        // Create borrowing position with correct WrappedUSDC1 type
        let positionId = self.borrowingManagerRef.createBorrowingPosition(
            collateralVault: <- self.collateralVault,
            borrowTokenType: Type<@WrappedETH1.Vault>(),
            borrowAmount: borrowAmount,
            durationMinutes: durationMinutes,
            borrower: self.signerAddress,
            borrowerRecipient: self.borrowedTokensReceiver,
            oraclePayment1: <- self.oraclePayment1,
            oraclePayment2: <- self.oraclePayment2
        )

        if positionId == nil {
            panic("Failed to create borrowing position - borrow amount exceeds LTV limit")
        }
        
        log("Successfully created borrowing position with ID: ".concat(positionId!.toString()))
        log("Collateral locked: ".concat(collateralAmount.toString()).concat(" WrappedETH"))
        log("Borrowed: ".concat(borrowAmount.toString()).concat(" WrappedUSDC"))
        log("Duration: ".concat(durationMinutes.toString()).concat(" minutes"))
    }
}`

// Borrow USDC using FLOW collateral
const BORROW_USDC_FLOW_COLLATERAL_TX = `
import FungibleToken from 0x9a0766d93b6608b7
import FlowToken from 0x7e60df042a9c0868
import TimeLendingProtocol2 from 0xe11cab85e85ae137
import WrappedUSDC1 from 0xe11cab85e85ae137
import BandOracle from 0x9fb6606c300b5051

transaction(
    collateralAmount: UFix64,
    borrowAmount: UFix64,
    durationMinutes: UInt64
) {
    let borrowingManagerRef: &TimeLendingProtocol2.BorrowingManager
    let collateralVault: @{FungibleToken.Vault}
    let borrowedTokensReceiver: &{FungibleToken.Receiver}
    let oraclePayment1: @{FungibleToken.Vault}
    let oraclePayment2: @{FungibleToken.Vault}
    let signerAddress: Address
    
    prepare(signer: auth(BorrowValue, Storage, Capabilities) &Account) {
        self.signerAddress = signer.address
        self.borrowingManagerRef = TimeLendingProtocol2.borrowBorrowingManager()
        
        // Withdraw FLOW collateral from signer's vault
        let flowVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
            from: /storage/flowTokenVault
        ) ?? panic("Could not borrow FLOW vault from storage")
        
        self.collateralVault <- flowVault.withdraw(amount: collateralAmount)
        
        // Get receiver capability for borrowed USDC tokens
        self.borrowedTokensReceiver = signer.capabilities.get<&{FungibleToken.Receiver}>(
            WrappedUSDC1.ReceiverPublicPath
        ).borrow() ?? panic("Could not borrow USDC receiver capability. Make sure you have WrappedUSDC1 vault set up.")
        
        // Withdraw FLOW tokens for oracle payment (need to borrow vault again for additional withdrawals)
        let flowVaultForOracle = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
            from: /storage/flowTokenVault
        ) ?? panic("Could not borrow FLOW vault from storage for oracle payment")
        
        self.oraclePayment1 <- flowVaultForOracle.withdraw(amount: BandOracle.getFee())
        self.oraclePayment2 <- flowVaultForOracle.withdraw(amount: BandOracle.getFee())
    }
    
    execute {
        let positionId = self.borrowingManagerRef.createBorrowingPosition(
            collateralVault: <- self.collateralVault,
            borrowTokenType: Type<@WrappedUSDC1.Vault>(),
            borrowAmount: borrowAmount,
            durationMinutes: durationMinutes,
            borrower: self.signerAddress,
            borrowerRecipient: self.borrowedTokensReceiver,
            oraclePayment1: <- self.oraclePayment1,
            oraclePayment2: <- self.oraclePayment2
        )
        if positionId == nil { panic("Failed to create borrowing position - borrow amount exceeds LTV limit") }
    }
}`

// Borrow FLOW using WETH collateral
const BORROW_FLOW_TX = `
import FungibleToken from 0x9a0766d93b6608b7
import FlowToken from 0x7e60df042a9c0868
import TimeLendingProtocol2 from 0xe11cab85e85ae137
import WrappedETH1 from 0xe11cab85e85ae137
import BandOracle from 0x9fb6606c300b5051

transaction(
    collateralAmount: UFix64,
    borrowAmount: UFix64,
    durationMinutes: UInt64
) {
    let borrowingManagerRef: &TimeLendingProtocol2.BorrowingManager
    let collateralVault: @{FungibleToken.Vault}
    let borrowedTokensReceiver: &{FungibleToken.Receiver}
    let oraclePayment1: @{FungibleToken.Vault}
    let oraclePayment2: @{FungibleToken.Vault}
    let signerAddress: Address
    
    prepare(signer: auth(BorrowValue, Storage, Capabilities) &Account) {
        self.signerAddress = signer.address
        self.borrowingManagerRef = TimeLendingProtocol2.borrowBorrowingManager()
        let wrappedETHVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &{FungibleToken.Vault}>(
            from: WrappedETH1.VaultStoragePath
        ) ?? panic("Could not borrow Wrapped ETH vault from storage. Make sure you have WrappedETH1 vault set up.")
        self.collateralVault <- wrappedETHVault.withdraw(amount: collateralAmount)
        self.borrowedTokensReceiver = signer.capabilities.get<&{FungibleToken.Receiver}>(
            /public/flowTokenReceiver
        ).borrow() ?? panic("Could not borrow FLOW receiver capability. Make sure you have FLOW vault set up.")
        let flowVault = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
            from: /storage/flowTokenVault
        ) ?? panic("Could not borrow FLOW vault from storage")
        self.oraclePayment1 <- flowVault.withdraw(amount: BandOracle.getFee())
        self.oraclePayment2 <- flowVault.withdraw(amount: BandOracle.getFee())
    }
    
    execute {
        let positionId = self.borrowingManagerRef.createBorrowingPosition(
            collateralVault: <- self.collateralVault,
            borrowTokenType: Type<@FlowToken.Vault>(),
            borrowAmount: borrowAmount,
            durationMinutes: durationMinutes,
            borrower: self.signerAddress,
            borrowerRecipient: self.borrowedTokensReceiver,
            oraclePayment1: <- self.oraclePayment1,
            oraclePayment2: <- self.oraclePayment2
        )
        if positionId == nil { panic("Failed to create borrowing position - borrow amount exceeds LTV limit") }
    }
}`

export async function createBorrowUSDC(collateralAmount, borrowAmount, durationMinutes) {
  const args = [
    fcl.arg(parseFloat(collateralAmount).toFixed(8), t.UFix64),
    fcl.arg(parseFloat(borrowAmount).toFixed(8), t.UFix64),
    fcl.arg(String(durationMinutes), t.UInt64)
  ]
  return executeTransaction(BORROW_USDC_TX, args)
}

export async function createBorrowWETH(collateralAmount, borrowAmount, durationMinutes) {
  const args = [
    fcl.arg(parseFloat(collateralAmount).toFixed(8), t.UFix64),
    fcl.arg(parseFloat(borrowAmount).toFixed(8), t.UFix64),
    fcl.arg(String(durationMinutes), t.UInt64)
  ]
  return executeTransaction(BORROW_WETH_TX, args)
}

export async function createBorrowFLOW(collateralAmount, borrowAmount, durationMinutes) {
  const args = [
    fcl.arg(parseFloat(collateralAmount).toFixed(8), t.UFix64),
    fcl.arg(parseFloat(borrowAmount).toFixed(8), t.UFix64),
    fcl.arg(String(durationMinutes), t.UInt64)
  ]
  return executeTransaction(BORROW_FLOW_TX, args)
}

export async function createBorrowUSDCWithFlowCollateral(collateralAmount, borrowAmount, durationMinutes) {
  const args = [
    fcl.arg(parseFloat(collateralAmount).toFixed(8), t.UFix64),
    fcl.arg(parseFloat(borrowAmount).toFixed(8), t.UFix64),
    fcl.arg(String(durationMinutes), t.UInt64)
  ]
  return executeTransaction(BORROW_USDC_FLOW_COLLATERAL_TX, args)
}


