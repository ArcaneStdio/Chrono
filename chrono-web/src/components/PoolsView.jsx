import { useState, useEffect } from 'react'
import { motion } from 'framer-motion'// eslint-disable-line no-unused-vars
import { 
  SearchIcon, 
  GridIcon, 
  ListIcon 
} from './Icons'

export default function PoolsView({ isWalletConnected, onConnect, userAddress }) {
  const [activeTab, setActiveTab] = useState('pools')
  const [viewMode, setViewMode] = useState('grid')
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    setIsLoading(true)
    const timer = setTimeout(() => {
      setIsLoading(false)
    }, 700)
    return () => clearTimeout(timer)
  }, [])

  const swapVolume = "444.34M"
  const availableLiquidity = "14.28M"

  const pools = [
    {
      protocol: 'Euler Prime',
      baseAsset: 'USDC',
      quoteAsset: 'USDT',
      baseIcon: '',
      quoteIcon: '',
      lpNav: '$2.06M',
      volume24h: '$126.97M',
      currentPrice: '1.000157',
      pricePair: 'USDC/USDT',
      lpPnl: '-$24.17K',
      lpPnlPercent: '-$10.4K 24h',
      roe7d: '-15.22%',
      swapOperator: '0x4fD5...68a8',
      createdAt: 'Aug 29, 2025',
      isNegativePnl: true
    },
    {
      protocol: 'Euler Yield',
      baseAsset: 'RLUSD',
      quoteAsset: 'USDT',
      baseIcon: '',
      quoteIcon: '',
      lpNav: '$1.85M',
      volume24h: '$89.45M',
      currentPrice: '1.000089',
      pricePair: 'RLUSD/USDT',
      lpPnl: '+$18.92K',
      lpPnlPercent: '+$8.2K 24h',
      roe7d: '+12.45%',
      swapOperator: '0xF87A...a8A8',
      createdAt: 'Aug 12, 2025',
      isNegativePnl: false
    }
  ]

  const SkeletonPool = () => (
    <div className="bg-neutral-800/30 border border-neutral-700 rounded-xl p-6">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <div className="flex items-center">
            <div className="w-10 h-10 rounded-full bg-neutral-700 animate-shimmer"></div>
            <div className="w-10 h-10 rounded-full bg-neutral-700 animate-shimmer -ml-3"></div>
          </div>
          <div className="space-y-2">
            <div className="h-3 w-24 bg-neutral-700 rounded animate-shimmer"></div>
            <div className="h-5 w-32 bg-neutral-700 rounded animate-shimmer"></div>
          </div>
        </div>
      </div>
      <div className="grid grid-cols-5 gap-6">
        {[...Array(5)].map((_, i) => (
          <div key={i} className="space-y-2">
            <div className="h-3 w-20 bg-neutral-700 rounded animate-shimmer"></div>
            <div className="h-5 w-24 bg-neutral-700 rounded animate-shimmer"></div>
          </div>
        ))}
      </div>
    </div>
  )

  return (
    <div className="space-y-6">
      <motion.div 
        className="flex flex-col md:flex-row md:items-start md:justify-between gap-4 md:gap-6"
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
      >
        <div className="flex items-start gap-3 md:gap-4">
          <div className="w-12 h-12 md:w-16 md:h-16 rounded-xl bg-neutral-800 border border-neutral-700 flex items-center justify-center mt-1 flex-shrink-0">
            <svg className="w-6 h-6 md:w-8 md:h-8 text-[#c5ff4a]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
            </svg>
          </div>
          <div>
            <h1 className="text-2xl md:text-3xl font-bold text-white mb-1 md:mb-2">Pools</h1>
            <p className="text-gray-400 text-xs md:text-sm max-w-2xl">
              Browse pools or add liquidity on EulerSwap. Smarter yield, deeper liquidity, and LPs as collateral.
            </p>
          </div>
        </div>

        <div className="flex gap-6 md:gap-12 md:mt-2">
          <motion.div 
            className="text-left md:text-right"
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.4, delay: 0.1 }}
          >
            <p className="text-gray-500 text-xs mb-1">7d swap volume</p>
            {isLoading ? (
              <div className="h-6 md:h-8 w-24 md:w-32 bg-neutral-700 rounded animate-shimmer"></div>
            ) : (
              <p className="text-xl md:text-2xl font-semibold text-gray-300">$ {swapVolume}</p>
            )}
          </motion.div>
          <motion.div 
            className="text-left md:text-right"
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.4, delay: 0.2 }}
          >
            <p className="text-gray-500 text-xs mb-1">Available liquidity</p>
            {isLoading ? (
              <div className="h-6 md:h-8 w-24 md:w-32 bg-neutral-700 rounded animate-shimmer"></div>
            ) : (
              <p className="text-xl md:text-2xl font-semibold text-gray-300">$ {availableLiquidity}</p>
            )}
          </motion.div>
        </div>
      </motion.div>

      <div className="border-b border-neutral-700">
        <div className="flex gap-8">
          <button
            onClick={() => setActiveTab('pools')}
            className={`pb-3 px-1 text-sm font-medium transition-colors relative ${
              activeTab === 'pools'
                ? 'text-white'
                : 'text-gray-500 hover:text-gray-300'
            }`}
          >
            Pools
            {activeTab === 'pools' && (
              <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-[#c5ff4a]"></div>
            )}
          </button>
          <button
            onClick={() => setActiveTab('incentivised')}
            className={`pb-3 px-1 text-sm font-medium transition-colors relative ${
              activeTab === 'incentivised'
                ? 'text-white'
                : 'text-gray-500 hover:text-gray-300'
            }`}
          >
            Incentivised pairs
            {activeTab === 'incentivised' && (
              <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-[#c5ff4a]"></div>
            )}
          </button>
        </div>
      </div>

      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-3">
        <div className="flex flex-wrap items-center gap-2 md:gap-3">
          <div className="hidden md:flex items-center gap-2 px-3 py-2 bg-neutral-800/50 border border-neutral-700 rounded-lg text-sm">
            <span className="text-gray-400">Base asset is</span>
            <button className="px-2 py-0.5 bg-neutral-700 hover:bg-neutral-600 rounded text-white font-medium">
              any asset
            </button>
          </div>

          <div className="hidden md:flex items-center gap-2 px-3 py-2 bg-neutral-800/50 border border-neutral-700 rounded-lg text-sm">
            <span className="text-gray-400">Quote asset is</span>
            <button className="px-2 py-0.5 bg-neutral-700 hover:bg-neutral-600 rounded text-white font-medium">
              any asset
            </button>
          </div>

          <div className="hidden md:flex items-center gap-2 px-3 py-2 bg-neutral-800/50 border border-neutral-700 rounded-lg text-sm">
            <span className="text-gray-400">Available liquidity is</span>
            <button className="px-2 py-0.5 bg-neutral-700 hover:bg-neutral-600 rounded text-white font-medium">
              &gt;$1,000
            </button>
            <button className="text-gray-400 hover:text-white">
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </button>
          </div>

          <div className="hidden md:flex items-center gap-2 px-3 py-2 bg-neutral-800/50 border border-neutral-700 rounded-lg text-sm">
            <span className="text-gray-400">LP NAV is</span>
            <button className="px-2 py-0.5 bg-neutral-700 hover:bg-neutral-600 rounded text-white font-medium">
              anything
            </button>
          </div>

          <div className="flex items-center gap-2 px-3 py-2 bg-neutral-800/50 border border-neutral-700 rounded-lg text-sm">
            <span className="text-gray-400 text-xs md:text-sm">Known assets only</span>
            <button className="w-10 h-5 bg-[#c5ff4a] rounded-full relative">
              <div className="absolute right-0.5 top-0.5 w-4 h-4 bg-white rounded-full"></div>
            </button>
          </div>
        </div>

        <button className="w-full md:w-auto px-6 py-2 bg-[#c5ff4a] hover:bg-[#b0e641] text-neutral-900 font-semibold rounded-lg transition-colors">
          Create Pool
        </button>
      </div>

      <div className="flex items-center gap-2">
        <button
          onClick={() => setViewMode('grid')}
          className={`p-2 rounded ${
            viewMode === 'grid'
              ? 'bg-[#c5ff4a]/10 text-[#c5ff4a]'
              : 'bg-neutral-800/50 text-gray-400 hover:text-gray-300'
          }`}
        >
          <GridIcon />
        </button>
        <button
          onClick={() => setViewMode('list')}
          className={`p-2 rounded ${
            viewMode === 'list'
              ? 'bg-[#c5ff4a]/10 text-[#c5ff4a]'
              : 'bg-neutral-800/50 text-gray-400 hover:text-gray-300'
          }`}
        >
          <ListIcon />
        </button>
      </div>

      <div className="space-y-4">
        {isLoading ? (
          <>
            <SkeletonPool />
            <SkeletonPool />
          </>
        ) : (
          pools.map((pool, index) => (
          <motion.div 
            key={index}
            className="bg-neutral-800/30 border border-neutral-700 rounded-xl p-4 md:p-6 hover:border-neutral-600 transition-colors"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ 
              duration: 0.4, 
              delay: index * 0.1,
              ease: [0.4, 0, 0.2, 1]
            }}
          >
            <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4 mb-6">
              <div className="flex items-center gap-3">
                <div className="flex items-center">
                  <div className="w-8 h-8 md:w-10 md:h-10 rounded-full bg-neutral-700 border-2 border-neutral-800 flex items-center justify-center text-base md:text-lg">
                    $
                  </div>
                  <div className="w-8 h-8 md:w-10 md:h-10 rounded-full bg-neutral-700 border-2 border-neutral-800 flex items-center justify-center -ml-2 md:-ml-3 text-base md:text-lg">
                    T
                  </div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 mb-0.5">{pool.protocol}</div>
                  <div className="text-lg md:text-xl font-bold text-white">{pool.baseAsset} / {pool.quoteAsset}</div>
                </div>
              </div>

              <div className="hidden md:flex items-center gap-6 text-sm">
                <div>
                  <span className="text-gray-400">Swap operator</span>
                  <span className="ml-2 text-[#c5ff4a] hover:text-[#b0e641] cursor-pointer">
                    {pool.swapOperator}
                  </span>
                </div>
                <div className="text-gray-500">
                  Created at {pool.createdAt}
                </div>
                <button className="text-gray-400 hover:text-white flex items-center gap-1">
                  Spy position
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                  </svg>
                </button>
              </div>
            </div>

            <div className="grid grid-cols-2 md:grid-cols-5 gap-4 md:gap-6">
              <div>
                <div className="text-xs text-gray-500 mb-1">LP NAV</div>
                <div className="text-lg font-semibold text-white">{pool.lpNav}</div>
              </div>
              <div>
                <div className="text-xs text-gray-500 mb-1">24 hr volume</div>
                <div className="text-lg font-semibold text-white">{pool.volume24h}</div>
              </div>
              <div>
                <div className="text-xs text-gray-500 mb-1">Current price</div>
                <div className="flex items-center gap-2">
                  <div className="text-lg font-semibold text-white">{pool.currentPrice}</div>
                  <button className="text-gray-400 hover:text-white">
                    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                    </svg>
                  </button>
                </div>
                <div className="text-xs text-gray-500">{pool.pricePair}</div>
              </div>
              <div>
                <div className="text-xs text-gray-500 mb-1">LP P&L</div>
                <div className={`text-lg font-semibold ${
                  pool.isNegativePnl ? 'text-red-400' : 'text-green-400'
                }`}>
                  {pool.lpPnl}
                </div>
                <div className="text-xs text-gray-500">{pool.lpPnlPercent}</div>
              </div>
              <div>
                <div className="text-xs text-gray-500 mb-1">7d combined ROE</div>
                <div className={`text-lg font-semibold ${
                  pool.isNegativePnl ? 'text-red-400' : 'text-green-400'
                }`}>
                  {pool.roe7d}
                </div>
              </div>
              <div>
                <button className="w-full mt-4 md:mt-0 px-4 py-2 bg-[#c5ff4a] hover:bg-[#b0e641] text-neutral-900 font-semibold rounded-lg transition-colors">
                  Add Liquidity
                </button>
              </div>
            </div>
          </motion.div>
        )))}
      </div>

      {activeTab === 'incentivised' && (
        <div className="text-center py-16">
          <div className="text-gray-500">No incentivised pairs available</div>
        </div>
      )}
    </div>
  )
}
