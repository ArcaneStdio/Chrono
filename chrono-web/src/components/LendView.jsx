import { useState, useEffect } from 'react'
import { motion } from 'framer-motion'// eslint-disable-line no-unused-vars
import { SearchIcon, TrendUpIcon, SortIcon } from './Icons'
import LendPositionView from './LendPositionView'
import { fetchVaultData, transformForLendView, getProtocolStats } from '../utils/vaultData'

export default function LendView() {
  const [inWallet, setInWallet] = useState(true)
  const [searchQuery, setSearchQuery] = useState('')
  const [selectedAsset, setSelectedAsset] = useState(null)
  const [isLoading, setIsLoading] = useState(true)
  const [vaultData, setVaultData] = useState(null)
  const [error, setError] = useState(null)

  // Fetch vault data on component mount
  useEffect(() => {
    async function loadVaultData() {
      try {
        setIsLoading(true)
        const data = await fetchVaultData()
        setVaultData(data)
        setError(null)
      } catch (err) {
        console.error('Failed to load vault data:', err)
        setError(err.message)
      } finally {
        setIsLoading(false)
      }
    }
    
    loadVaultData()
    
    // Refresh data every 5 minutes
    const interval = setInterval(loadVaultData, 5 * 60 * 1000)
    return () => clearInterval(interval)
  }, [])

  const protocolStats = vaultData ? getProtocolStats(vaultData) : null
  const totalBorrow = protocolStats?.totalBorrowed || "$0"
  const totalBorrowUSD = "on Flow Testnet"
  const totalSupply = protocolStats?.totalValueLocked || "$0"
  const totalSupplyUSD = "on Flow Testnet"
  // Transform vault data for display
  const allAssets = vaultData ? transformForLendView(vaultData) : []

  const filteredAssets = allAssets.filter(asset => 
    asset.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    asset.symbol.toLowerCase().includes(searchQuery.toLowerCase()) ||
    asset.protocol.toLowerCase().includes(searchQuery.toLowerCase())
  )


  const getUtilizationColor = (percent) => {
    if (percent === 0) return 'bg-gray-600'
    if (percent < 50) return 'bg-neutral-500'
    if (percent < 80) return 'bg-orange-500'
    return 'bg-green-500'
  }

  if (selectedAsset) {
    return <LendPositionView asset={selectedAsset} onBack={() => setSelectedAsset(null)} />
  }

  const SkeletonRow = () => (
    <tr className="border-b border-neutral-700/50">
      <td className="p-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-full bg-neutral-700 animate-shimmer"></div>
          <div className="space-y-2">
            <div className="h-4 w-24 bg-neutral-700 rounded animate-shimmer"></div>
            <div className="h-3 w-16 bg-neutral-700 rounded animate-shimmer"></div>
          </div>
        </div>
      </td>
      <td className="p-4">
        <div className="flex items-center gap-2">
          <div className="w-6 h-6 rounded-full bg-neutral-700 animate-shimmer"></div>
          <div className="h-4 w-20 bg-neutral-700 rounded animate-shimmer"></div>
        </div>
      </td>
      <td className="p-4">
        <div className="h-5 w-16 bg-neutral-700 rounded animate-shimmer"></div>
      </td>
      <td className="p-4">
        <div className="space-y-2">
          <div className="h-4 w-24 bg-neutral-700 rounded animate-shimmer"></div>
          <div className="h-3 w-32 bg-neutral-700 rounded animate-shimmer"></div>
        </div>
      </td>
      <td className="p-4">
        <div className="h-5 w-16 bg-neutral-700 rounded animate-shimmer"></div>
      </td>
      <td className="p-4">
        <div className="h-5 w-24 bg-neutral-700 rounded animate-shimmer"></div>
      </td>
    </tr>
  )

  return (
    <div className="space-y-6">
      <motion.div 
        className="flex flex-col md:flex-row md:items-start md:justify-between gap-6"
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
      >
        <div className="flex items-start gap-3 md:gap-4">
          <div className="w-12 h-12 md:w-16 md:h-16 rounded-xl bg-neutral-800 border border-neutral-700 flex items-center justify-center mt-1 flex-shrink-0">
            <svg className="w-6 h-6 md:w-8 md:h-8 text-[#c5ff4a]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M9 19l3 3m0 0l3-3m-3 3V10" />
            </svg>
          </div>
          <div>
            <h1 className="text-2xl md:text-3xl font-bold text-white mb-1 md:mb-2">Lend</h1>
            <p className="text-gray-400 text-xs md:text-sm">Earn yield on assets by lending them out.</p>
          </div>
        </div>

        <div className="flex gap-4 md:gap-8">
          <motion.div 
            className="text-left md:text-right"
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.4, delay: 0.1 }}
          >
            <p className="text-gray-500 text-xs mb-1">Total borrow</p>
            {isLoading ? (
              <div className="h-6 md:h-8 w-24 md:w-32 bg-neutral-700 rounded animate-shimmer mb-1"></div>
            ) : (
              <p className="text-xl md:text-2xl font-semibold text-gray-300">$ {totalBorrow}</p>
            )}
            <p className="text-xs text-gray-500 hidden md:block">{totalBorrowUSD}</p>
          </motion.div>
          <motion.div 
            className="text-left md:text-right"
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.4, delay: 0.2 }}
          >
            <p className="text-gray-500 text-xs mb-1">Total supply</p>
            {isLoading ? (
              <div className="h-6 md:h-8 w-24 md:w-32 bg-neutral-700 rounded animate-shimmer mb-1"></div>
            ) : (
              <p className="text-xl md:text-2xl font-semibold text-gray-300">$ {totalSupply}</p>
            )}
            <p className="text-xs text-gray-500 hidden md:block">{totalSupplyUSD}</p>
          </motion.div>
        </div>
      </motion.div>

      <div className="flex flex-col md:flex-row md:items-center gap-3 md:gap-4">
        <div className="relative flex-1 md:max-w-xs">
          <input
            type="text"
            placeholder="Search assets..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-10 pr-4 py-2 bg-neutral-800 border border-neutral-700 rounded-lg text-white placeholder-gray-500 focus:outline-none focus:border-neutral-600"
          />
          <div className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500">
            <SearchIcon className="w-5 h-5" />
          </div>
        </div>

        <div className="hidden md:flex items-center gap-2 px-3 py-2 bg-neutral-800 border border-neutral-700 rounded-lg text-sm">
          <span className="text-gray-400">Asset is</span>
          <button className="px-2 py-0.5 bg-neutral-700 hover:bg-neutral-600 rounded text-white font-medium">
            any asset
          </button>
        </div>

        <div className="hidden md:flex items-center gap-2 px-3 py-2 bg-neutral-800 border border-neutral-700 rounded-lg text-sm">
          <span className="text-gray-400">Market is</span>
          <button className="px-2 py-0.5 bg-neutral-700 hover:bg-neutral-600 rounded text-white font-medium">
            any market
          </button>
        </div>

        <div className="hidden md:flex items-center gap-2 px-3 py-2 bg-neutral-800 border border-neutral-700 rounded-lg text-sm">
          <span className="text-gray-400">Risk curator is</span>
          <button className="px-2 py-0.5 bg-neutral-700 hover:bg-neutral-600 rounded text-white font-medium">
            anyone
          </button>
        </div>

        <button 
          onClick={() => setInWallet(!inWallet)}
          className={`md:ml-auto flex items-center justify-between gap-2 px-4 py-2 rounded-lg transition-all border ${
            inWallet 
              ? 'bg-neutral-700 border-neutral-600 text-white' 
              : 'bg-neutral-800 border-neutral-700 text-gray-400'
          }`}
        >
          <span>In wallet</span>
          <div className={`w-10 h-5 rounded-full relative transition-colors ${
            inWallet ? 'bg-[#c5ff4a]' : 'bg-neutral-600'
          }`}>
            <div className={`absolute top-0.5 w-4 h-4 bg-white rounded-full transition-all ${
              inWallet ? 'right-0.5' : 'left-0.5'
            }`}></div>
          </div>
          
        </button>
      </div>

      {error && (
        <div className="bg-red-900/20 border border-red-700 rounded-xl p-4 text-red-400">
          <p className="font-semibold">Failed to load vault data</p>
          <p className="text-sm mt-1">{error}</p>
          <p className="text-xs mt-2">Make sure vault.json is up to date. Run: node update-vault-data.js</p>
        </div>
      )}

      <div className="bg-neutral-800/30 border border-neutral-700 rounded-xl overflow-x-auto">
        <table className="w-full min-w-[800px]">
          <thead>
            <tr className="border-b border-neutral-700">
              <th className="text-left p-4 text-gray-400 font-medium text-sm">
                <button className="flex items-center gap-1 hover:text-white transition-colors">
                  Asset
                  <SortIcon />
                </button>
              </th>
              <th className="text-left p-4 text-gray-400 font-medium text-sm">Risk curator</th>
              <th className="text-left p-4 text-gray-400 font-medium text-sm">
                <button className="flex items-center gap-1 hover:text-white transition-colors">
                  Supply APY
                  <SortIcon />
                </button>
              </th>
              <th className="text-left p-4 text-gray-400 font-medium text-sm">
                <button className="flex items-center gap-1 hover:text-white transition-colors">
                  Total supply
                  <SortIcon />
                </button>
              </th>
              <th className="text-left p-4 text-gray-400 font-medium text-sm">Exposure</th>
              <th className="text-left p-4 text-gray-400 font-medium text-sm">
                <button className="flex items-center gap-1 hover:text-white transition-colors">
                  Utilization
                  <SortIcon />
                </button>
              </th>
            </tr>
          </thead>
          <tbody>
            {isLoading ? (
              <>
                <SkeletonRow />
                <SkeletonRow />
                <SkeletonRow />
                <SkeletonRow />
              </>
            ) : (
              filteredAssets.map((asset, index) => (
              <motion.tr 
                key={index}
                onClick={() => setSelectedAsset(asset)}
                className="border-b border-neutral-700/50 hover:bg-neutral-800/50 transition-colors cursor-pointer"
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ 
                  duration: 0.3, 
                  delay: index * 0.05,
                  ease: [0.4, 0, 0.2, 1]
                }}
              >
                <td className="p-4">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-full bg-neutral-700 flex items-center justify-center text-white font-semibold">
                      {asset.symbol.substring(0, 2)}
                    </div>
                    <div>
                      <div className="text-white font-medium">{asset.name}</div>
                      <div className="text-gray-400 text-sm">{asset.symbol}</div>
                    </div>
                  </div>
                </td>
                <td className="p-4">
                  <div className="flex items-center gap-2">
                    <div className="w-6 h-6 rounded-full bg-neutral-600 flex items-center justify-center text-xs text-white">
                      {asset.protocol[0]}
                    </div>
                    <span className="text-gray-300 text-sm">{asset.protocol}</span>
                  </div>
                </td>
                <td className="p-4">
                  <div className="flex items-center gap-1">
                    <TrendUpIcon className="w-4 h-4 text-green-400" />
                    <span className="text-white font-medium">{asset.supplyAPY}</span>
                  </div>
                </td>
                <td className="p-4">
                  <div>
                    <div className="text-white font-medium">{asset.totalSupply}</div>
                    <div className="text-gray-400 text-sm">{asset.totalSupplyToken}</div>
                  </div>
                </td>
                <td className="p-4">
                  <div className="flex items-center gap-1">
                    {asset.exposure > 0 ? (
                      <div className="flex items-center gap-1">
                        <div className="w-5 h-5 rounded-full bg-neutral-600 border border-neutral-500"></div>
                        <div className="w-5 h-5 rounded-full bg-neutral-600 border border-neutral-500 -ml-2"></div>
                        {asset.exposure > 2 && (
                          <span className="text-gray-400 text-sm ml-1">+{asset.exposure - 2}</span>
                        )}
                      </div>
                    ) : (
                      <span className="text-gray-500">—</span>
                    )}
                  </div>
                </td>
                <td className="p-4">
                  <div className="flex items-center gap-2">
                    <div className="w-24 h-2 bg-neutral-700 rounded-full overflow-hidden">
                      <div 
                        className={`h-full ${getUtilizationColor(asset.utilizationPercent)}`}
                        style={{ width: asset.utilization }}
                      ></div>
                    </div>
                    <span className="text-gray-300 font-medium text-sm">
                      {asset.utilization}
                    </span>
                  </div>
                </td>
              </motion.tr>
            )))}
            {!isLoading && filteredAssets.length === 0 && (
              <tr>
                <td colSpan="6" className="p-8 text-center text-gray-500">
                  No assets found matching "{searchQuery}"
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}
