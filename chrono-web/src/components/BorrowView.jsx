import { TrendUpIcon, InfoIcon } from './Icons'
import { useState } from 'react'
import BorrowPositionView from './BorrowPositionView'

export default function BorrowView() {
  const [selectedAsset, setSelectedAsset] = useState(null)
  const borrowAssets = [
    {
      name: 'FLOW',
      symbol: 'FLOW',
      protocol: 'Flow',
      borrowAPY: '5.42%',
      available: '$45.20M',
      availableToken: '30.50M FLOW',
      maxLTV: '75%',
      liquidationThreshold: '85%'
    },
    {
      name: 'Wrapped ETH',
      symbol: 'WETH',
      protocol: 'Chrono',
      borrowAPY: '2.15%',
      available: '$15.80M',
      availableToken: '3,750.20 WETH',
      maxLTV: '70%',
      liquidationThreshold: '80%'
    },
    {
      name: 'USDC',
      symbol: 'USDC',
      protocol: 'Chrono',
      borrowAPY: '8.25%',
      available: '$85.40M',
      availableToken: '85.40M USDC',
      maxLTV: '80%',
      liquidationThreshold: '90%'
    }
  ]

  if (selectedAsset) {
    return <BorrowPositionView asset={selectedAsset} onBack={() => setSelectedAsset(null)} />
  }

  return (
    <div className="space-y-6">
      <div className="flex items-start justify-between">
        <div className="flex items-start gap-4">
          <div className="w-16 h-16 rounded-xl bg-neutral-800 border border-neutral-700 flex items-center justify-center mt-1">
            <svg className="w-8 h-8 text-[#c5ff4a]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z" />
            </svg>
          </div>
          <div>
            <h1 className="text-3xl font-bold text-white mb-2">Borrow</h1>
            <p className="text-gray-400 text-sm">Borrow assets using your collateral with dynamic LTV.</p>
          </div>
        </div>

        <div className="bg-neutral-800/50 border border-neutral-700 rounded-xl p-4 max-w-md">
          <div className="flex items-start gap-2">
            <InfoIcon className="w-5 h-5 text-[#c5ff4a] mt-0.5" />
            <div>
              <h3 className="text-white font-semibold mb-1">Time-Based LTV</h3>
              <p className="text-gray-400 text-sm">
                Chrono uses dynamic LTV that adjusts based on your loan duration. 
                Shorter loans get higher LTV ratios.
              </p>
            </div>
          </div>
        </div>
      </div>

      <div className="bg-neutral-800/30 border border-neutral-700 rounded-xl p-6">
        <h2 className="text-xl font-bold text-white mb-4">Your Active Positions</h2>
        <div className="text-center py-12">
          <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-neutral-800 flex items-center justify-center">
            <svg className="w-8 h-8 text-gray-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
            </svg>
          </div>
          <p className="text-gray-400">No active borrowing positions</p>
          <p className="text-gray-500 text-sm mt-2">Connect your wallet to view or create positions</p>
        </div>
      </div>

      <div className="bg-neutral-800/30 border border-neutral-700 rounded-xl overflow-hidden">
        <div className="p-6 border-b border-neutral-700">
          <h2 className="text-xl font-bold text-white">Available to Borrow</h2>
        </div>
        
        <table className="w-full">
          <thead>
            <tr className="border-b border-neutral-700">
              <th className="text-left p-4 text-gray-400 font-medium text-sm">Asset</th>
              <th className="text-left p-4 text-gray-400 font-medium text-sm">Protocol</th>
              <th className="text-left p-4 text-gray-400 font-medium text-sm">Borrow APY</th>
              <th className="text-left p-4 text-gray-400 font-medium text-sm">Available Liquidity</th>
              <th className="text-left p-4 text-gray-400 font-medium text-sm">Max LTV</th>
              <th className="text-left p-4 text-gray-400 font-medium text-sm">Liquidation Threshold</th>
            </tr>
          </thead>
          <tbody>
            {borrowAssets.map((asset, index) => (
              <tr 
                key={index}
                onClick={() => setSelectedAsset(asset)}
                className="border-b border-neutral-700/50 hover:bg-neutral-800/50 transition-colors cursor-pointer"
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
                  <span className="text-gray-300 text-sm">{asset.protocol}</span>
                </td>
                <td className="p-4">
                  <div className="flex items-center gap-1">
                    <TrendUpIcon className="w-4 h-4 text-red-400" />
                    <span className="text-white font-medium">{asset.borrowAPY}</span>
                  </div>
                </td>
                <td className="p-4">
                  <div>
                    <div className="text-white font-medium">{asset.available}</div>
                    <div className="text-gray-400 text-sm">{asset.availableToken}</div>
                  </div>
                </td>
                <td className="p-4">
                  <span className="text-[#c5ff4a] font-medium">{asset.maxLTV}</span>
                </td>
                <td className="p-4">
                  <span className="text-orange-400 font-medium">{asset.liquidationThreshold}</span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
