import { useState } from 'react'
import { motion } from 'framer-motion' // eslint-disable-line no-unused-vars
import IRMGraph from './IRMGraph'
import { createLendingPosition } from '../utils/lending-transaction-eth'

export default function LendPositionView({
  asset,
  onBack,
  isWalletConnected,
  onConnect,
  userAddress
}) {
  const [supplyAmount, setSupplyAmount] = useState('')

  const vaultData = {
    totalSupply: asset.totalSupply || 'not coming',
    totalSupplyTokens: asset.totalSupplyTokens || 'not coming',
    supplyAPY: asset.supplyAPY || 'not coming',
    utilization: asset.utilization || 'not coming',
    totalBorrowed: asset.totalBorrowed || 'not coming',
    availableLiquidity: asset.available || 'not coming',
    borrowAPY: asset.borrowAPY || 'not coming',
    oraclePrice: asset.oraclePrice || 'not coming',
    market: asset.protocol || 'not coming',
    vaultType: asset.vaultType || 'not coming',
    canBeBorrowed: asset.canBeBorrowed || 'not coming',
    canBeUsedAsCollateral: asset.canBeUsedAsCollateral || 'not coming',
    liquidationPenalty: asset.liquidationPenalty || 'not coming',
    supplyCap: asset.supplyCap || 'not coming',
    supplyCapPercent: asset.supplyCapPercent || 'not coming',
    borrowCap: asset.borrowCap || 'not coming',
    borrowCapPercent: asset.borrowCapPercent || 'not coming',
    shareTokenRate: asset.shareTokenRate || 'not coming',
    badDebtSocialization: asset.badDebtSocialization || 'not coming',
    interestFee: asset.interestFee || 'not coming'
  }

  const handleSupply = async () => {
    if (parseFloat(supplyAmount) > 0) {
      try {
        const txId = await createLendingPosition(supplyAmount)
        console.log('Lending Transaction Sent. ID:', txId)
        setSupplyAmount('')
      } catch (error) {
        console.error('Failed to send Lending Transaction:', error)
      }
    }
  }

  return (
    <motion.div
      className="min-h-screen bg-neutral-950 pt-4 md:pt-8"
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -20 }}
      transition={{ duration: 0.3, ease: [0.4, 0, 0.2, 1] }}
    >
      <div className="container mx-auto px-4">
        <motion.button
          onClick={onBack}
          className="mb-4 md:mb-6 text-gray-400 hover:text-white flex items-center gap-2 transition-colors"
          whileHover={{ x: -4 }}
          whileTap={{ scale: 0.95 }}
        >
          <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
          Back to Lend
        </motion.button>

        <motion.div
          className="mb-6 md:mb-8"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.4, delay: 0.1 }}
        >
          <div className="flex items-center gap-3 mb-4">
            <div className="w-12 h-12 md:w-16 md:h-16 rounded-full bg-neutral-800 border-2 border-neutral-950 flex items-center justify-center text-white font-bold text-lg md:text-xl flex-shrink-0">
              {asset.symbol?.substring(0, 1) || '?'}
            </div>
            <div>
              <div className="text-xs text-gray-500">{vaultData.market}</div>
              <h1 className="text-2xl md:text-4xl font-bold text-white">{asset.symbol}</h1>
            </div>
          </div>

          <div className="grid grid-cols-3 gap-3 md:gap-8">
            <div>
              <div className="text-gray-500 text-xs md:text-sm mb-1">Total supply</div>
              <div className="text-lg md:text-3xl font-bold text-white">{vaultData.totalSupply}</div>
              <div className="text-xs text-gray-500 hidden md:block">{vaultData.totalSupplyTokens}</div>
            </div>
            <div>
              <div className="text-gray-500 text-xs md:text-sm mb-1">Supply APY</div>
              <div className="text-lg md:text-3xl font-bold text-white">{vaultData.supplyAPY}</div>
            </div>
            <div>
              <div className="text-gray-500 text-xs md:text-sm mb-1">Utilization</div>
              <div className="flex items-center gap-2 md:gap-3">
                <div className="w-8 h-8 md:w-12 md:h-12 rounded-full border-3 md:border-4 border-[#c5ff4a] border-t-transparent rotate-45"></div>
                <div className="text-lg md:text-3xl font-bold text-white">{vaultData.utilization}</div>
              </div>
            </div>
          </div>
        </motion.div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2 space-y-6">
            <motion.div
              className="bg-neutral-900 border border-neutral-800 rounded-xl p-4 md:p-6"
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.4, delay: 0.2 }}
            >
              <h3 className="text-lg md:text-xl font-bold text-white mb-4 md:mb-6">Overview</h3>
              <div className="grid grid-cols-2 md:grid-cols-3 gap-4 md:gap-6">
                <div>
                  <div className="text-xs text-gray-500 mb-2">Oracle price</div>
                  <div className="text-lg font-semibold text-white">{vaultData.oraclePrice}</div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 mb-2">Market</div>
                  <div className="text-lg font-semibold text-white">{vaultData.market}</div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 mb-2">Vault type</div>
                  <span className="text-sm font-medium text-white">{vaultData.vaultType}</span>
                </div>
              </div>
            </motion.div>

            <motion.div
              className="bg-neutral-900 border border-neutral-800 rounded-xl p-4 md:p-6"
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.4, delay: 0.3 }}
            >
              <h3 className="text-lg md:text-xl font-bold text-white mb-4 md:mb-6">Statistics</h3>
              <div className="grid grid-cols-2 md:grid-cols-3 gap-4 md:gap-6">
                <div>
                  <div className="text-xs text-gray-500 mb-2">Total borrowed</div>
                  <div className="text-xl font-bold text-white">{vaultData.totalBorrowed}</div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 mb-2">Available liquidity</div>
                  <div className="text-xl font-bold text-white">{vaultData.availableLiquidity}</div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 mb-2">Borrow APY</div>
                  <div className="text-xl font-bold text-white">{vaultData.borrowAPY}</div>
                </div>
              </div>
            </motion.div>

            <motion.div
              className="bg-neutral-900 border border-neutral-800 rounded-xl p-4 md:p-6"
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.4, delay: 0.4 }}
            >
              <div className="flex items-center gap-2 mb-4">
                <h3 className="text-lg md:text-xl font-bold text-white">Interest rate model</h3>
                <span className="px-2 py-0.5 bg-[#c5ff4a] text-neutral-900 text-xs font-semibold rounded">Kink</span>
              </div>
              <IRMGraph currentUtilization={parseFloat(vaultData.utilization) || 0} />
            </motion.div>
          </div>

          <div className="lg:sticky lg:top-8 h-fit">
            <div className="bg-neutral-900 border border-neutral-800 rounded-xl p-4 md:p-6">
              <h3 className="text-base md:text-lg font-semibold text-white mb-4 md:mb-6">
                Supply {asset.symbol}
              </h3>

              {isWalletConnected && (
                <div className="flex justify-between items-center text-xs mb-3">
                  <span className="text-gray-500">Connected Wallet</span>
                  <span className="text-[#c5ff4a] font-mono">{userAddress}</span>
                </div>
              )}

              <div className="mb-6">
                <input
                  type="number"
                  value={supplyAmount}
                  onChange={(e) => setSupplyAmount(e.target.value)}
                  placeholder="0"
                  className="w-full bg-neutral-800 border border-neutral-700 rounded-lg px-4 py-4 text-white text-2xl font-bold focus:outline-none focus:border-neutral-600"
                  disabled={!isWalletConnected}
                />
              </div>

              <div className="space-y-3 mb-6 text-sm">
                <div className="flex justify-between">
                  <span className="text-gray-400">Supply APY</span>
                  <span className="text-white font-medium">{vaultData.supplyAPY}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Estimated gas fee</span>
                  <span className="text-white font-medium">0 ETH <span className="text-gray-500">$0</span></span>
                </div>
              </div>

              {isWalletConnected ? (
                <button
                  onClick={handleSupply}
                  disabled={!supplyAmount || parseFloat(supplyAmount) <= 0}
                  className={`w-full font-semibold py-3 rounded-lg transition-colors ${
                    !supplyAmount || parseFloat(supplyAmount) <= 0
                      ? 'bg-neutral-700 text-gray-500 cursor-not-allowed'
                      : 'bg-[#c5ff4a] hover:bg-[#b0e641] text-neutral-900'
                  }`}
                >
                  Supply
                </button>
              ) : (
                <button
                  onClick={onConnect}
                  className="w-full font-semibold py-3 rounded-lg bg-[#c5ff4a] hover:bg-[#b0e641] text-neutral-900"
                >
                  Connect Wallet
                </button>
              )}
            </div>
          </div>
        </div>
      </div>
    </motion.div>
  )
}
