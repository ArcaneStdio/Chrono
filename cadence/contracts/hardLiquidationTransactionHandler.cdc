import FlowTransactionScheduler from 0x8c5303eaa26202d6
import LiquidationPool from 0xe11cab85e85ae137

access(all) contract LiquidationPoolTransactionHandler {

    access(all) struct PositionData {
        access(all) let positionId: UInt64
        access(all) let debtTokenType: String

        init(positionId: UInt64, debtTokenType: String) {
            self.positionId = positionId
            self.debtTokenType = debtTokenType
        }
    }

    /// Handler resource that implements the Scheduled Transaction interface
    access(all) resource Handler: FlowTransactionScheduler.TransactionHandler {
        access(FlowTransactionScheduler.Execute) fun executeTransaction(id: UInt64, data: AnyStruct?) {
            let positionData = data as! LiquidationPoolTransactionHandler.PositionData
            LiquidationPool.executeHardLiquidation(
                positionId: positionData.positionId,
                debtTokenType: positionData.debtTokenType
            )
        }

        access(all) view fun getViews(): [Type] {
            return [Type<StoragePath>(), Type<PublicPath>()]
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<StoragePath>():
                    return /storage/LiquidationPoolTransactionHandler
                case Type<PublicPath>():
                    return /public/LiquidationPoolTransactionHandler
                default:
                    return nil
            }
        }
    }

    /// Factory for the handler resource
    access(all) fun createHandler(): @Handler {
        return <- create Handler()
    }
}