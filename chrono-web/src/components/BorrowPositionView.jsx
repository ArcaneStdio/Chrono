import { useState, useEffect } from 'react'
import { InfoIcon } from './Icons'
import LTVGraph from './LTVGraph'
import LTGraph from './LTGraph'

export default function BorrowPositionView({ asset, onBack }) {
  const [activeTab, setActiveTab] = useState('pair')
  const [supplyAmount, setSupplyAmount] = useState('')
  const [borrowAmount, setBorrowAmount] = useState('')
  const [ltvPercent, setLtvPercent] = useState(0)
  const [timeMinutes, setTimeMinutes] = useState(0)
  const [timeHours, setTimeHours] = useState(0)
  const [timeDays, setTimeDays] = useState(0)

  const totalMinutes = timeDays * 24 * 60 + timeHours * 60 + timeMinutes

  const calculateMaxLTV = (t) => {
    if (t === 0) return 90 //Default max when no time set
    return Math.min(90, 75 + 15 * Math.exp(-0.000333 * t))
  }

  const calculateLT = (t) => {
    return 77 + 18 * Math.exp(-0.000333 * t)
  }

  const maxLTV = calculateMaxLTV(totalMinutes)
  const currentLT = calculateLT(totalMinutes)

  const handleSupplyChange = (value) => {
    setSupplyAmount(value)
    if (value && ltvPercent > 0) {
      const calculatedBorrow = (parseFloat(value) * ltvPercent) / 100
      setBorrowAmount(calculatedBorrow.toFixed(6))
    } else {
      setBorrowAmount('')
    }
  }

  const handleLtvChange = (value) => {
    const cappedLtv = Math.min(value, maxLTV)
    setLtvPercent(cappedLtv)
    if (supplyAmount) {
      const calculatedBorrow = (parseFloat(supplyAmount) * cappedLtv) / 100
      setBorrowAmount(calculatedBorrow.toFixed(6))
    }
  }

  const handleBorrowChange = (value) => {
    setBorrowAmount(value)
    if (supplyAmount && parseFloat(supplyAmount) > 0) {
      const calculatedLtv = (parseFloat(value) / parseFloat(supplyAmount)) * 100
      setLtvPercent(Math.min(calculatedLtv, maxLTV))
    }
  }

  useEffect(() => {
    if (ltvPercent > maxLTV) {
      handleLtvChange(maxLTV)
    }
  }, [totalMinutes])

  return (
    <div className="min-h-screen bg-neutral-950 pt-8">
      <div className="container mx-auto px-4">
        <button 
          onClick={onBack}
          className="mb-6 text-gray-400 hover:text-white flex items-center gap-2 transition-colors"
        >
          <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
          Back to Borrow
        </button>

        <div className="mb-8">
          <div className="flex items-center gap-3 mb-4">
            <div className="flex items-center">
              <div className="w-12 h-12 rounded-full bg-neutral-800 border-2 border-neutral-950 flex items-center justify-center text-white font-semibold">
                {asset.symbol.substring(0, 2)}
              </div>
              <div className="w-12 h-12 rounded-full bg-neutral-800 border-2 border-neutral-950 flex items-center justify-center -ml-4 text-white font-semibold">
                USD
              </div>
            </div>
            <div>
              <div className="text-xs text-gray-500">Chrono Protocol</div>
              <h1 className="text-3xl font-bold text-white">{asset.name} / USDC</h1>
            </div>
          </div>

          <div className="grid grid-cols-3 gap-8">
            <div>
              <div className="text-gray-500 text-sm mb-1">Liquidity</div>
              <div className="text-2xl font-bold text-white">{asset.available}</div>
              <div className="text-xs text-gray-500">{asset.availableToken}</div>
            </div>
            <div>
              <div className="text-gray-500 text-sm mb-1">Max multiplier</div>
              <div className="text-2xl font-bold text-white">16.65 x</div>
            </div>
            <div>
              <div className="text-gray-500 text-sm mb-1">Max ROE</div>
              <div className="text-2xl font-bold text-[#c5ff4a]">{maxLTV.toFixed(2)} %</div>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-3 gap-6">
          <div className="col-span-2 space-y-6">
            <div className="grid grid-cols-2 gap-6">
              <div className="bg-neutral-900 border border-neutral-800 rounded-xl p-6">
                <h3 className="text-lg font-semibold text-white mb-4">Loan-to-Value (LTV) Over Time</h3>
                <LTVGraph currentTime={totalMinutes} />
              </div>
              <div className="bg-neutral-900 border border-neutral-800 rounded-xl p-6">
                <h3 className="text-lg font-semibold text-white mb-4">Liquidation Threshold (LT) Over Time</h3>
                <LTGraph currentTime={totalMinutes} />
              </div>
            </div>

            <div className="border-b border-neutral-800 mb-6">
              <div className="flex gap-6">
                <button
                  onClick={() => setActiveTab('pair')}
                  className={`pb-3 px-1 text-sm font-medium transition-colors relative ${
                    activeTab === 'pair' ? 'text-white' : 'text-gray-500 hover:text-gray-300'
                  }`}
                >
                  <div className="flex items-center gap-2">
                    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
                    </svg>
                    Pair details
                  </div>
                  {activeTab === 'pair' && (
                    <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-[#c5ff4a]"></div>
                  )}
                </button>
                <button
                  onClick={() => setActiveTab('collateral')}
                  className={`pb-3 px-1 text-sm font-medium transition-colors relative ${
                    activeTab === 'collateral' ? 'text-white' : 'text-gray-500 hover:text-gray-300'
                  }`}
                >
                  <div className="flex items-center gap-2">
                    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    Collateral {asset.symbol}
                  </div>
                  {activeTab === 'collateral' && (
                    <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-[#c5ff4a]"></div>
                  )}
                </button>
                <button
                  onClick={() => setActiveTab('debt')}
                  className={`pb-3 px-1 text-sm font-medium transition-colors relative ${
                    activeTab === 'debt' ? 'text-white' : 'text-gray-500 hover:text-gray-300'
                  }`}
                >
                  <div className="flex items-center gap-2">
                    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    Debt USDC
                  </div>
                  {activeTab === 'debt' && (
                    <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-[#c5ff4a]"></div>
                  )}
                </button>
              </div>
            </div>

            <div className="bg-neutral-900 border border-neutral-800 rounded-xl p-6">
              {activeTab === 'pair' && (
                <div>
                  <h3 className="text-xl font-bold text-white mb-6">Overview</h3>
                  <div className="grid grid-cols-3 gap-6">
                    <div>
                      <div className="text-xs text-gray-500 mb-2">Oracle price</div>
                      <div className="text-lg font-semibold text-white">$1.00</div>
                      <div className="text-xs text-gray-500">{asset.symbol} ⇄</div>
                    </div>
                    <div>
                      <div className="text-xs text-gray-500 mb-2">Supply APY</div>
                      <div className="text-lg font-semibold text-[#c5ff4a]">35.03%</div>
                    </div>
                    <div>
                      <div className="text-xs text-gray-500 mb-2">Borrow APY</div>
                      <div className="text-lg font-semibold text-red-400">{asset.borrowAPY}</div>
                    </div>
                    <div>
                      <div className="text-xs text-gray-500 mb-2">Correlated assets</div>
                      <div className="text-lg font-semibold text-white">Yes</div>
                    </div>
                    <div>
                      <div className="text-xs text-gray-500 mb-2">Max LTV</div>
                      <div className="text-lg font-semibold text-white">{asset.maxLTV}</div>
                    </div>
                    <div>
                      <div className="text-xs text-gray-500 mb-2">LLTV</div>
                      <div className="text-lg font-semibold text-white">{asset.liquidationThreshold}</div>
                    </div>
                  </div>
                </div>
              )}
              {activeTab === 'collateral' && (
                <div>
                  <h3 className="text-xl font-bold text-white mb-4">Collateral Details</h3>
                  <p className="text-gray-400">Information about {asset.symbol} collateral will be displayed here.</p>
                </div>
              )}
              {activeTab === 'debt' && (
                <div>
                  <h3 className="text-xl font-bold text-white mb-4">Debt Details</h3>
                  <p className="text-gray-400">Information about USDC debt will be displayed here.</p>
                </div>
              )}
            </div>
          </div>

          <div>
            <div className="bg-neutral-900 border border-neutral-800 rounded-xl p-6">
              <div className="border-b border-neutral-800 mb-6">
                <button className="pb-3 px-1 text-sm font-medium text-white relative">
                  Borrow
                  <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-[#c5ff4a]"></div>
                </button>
              </div>

              <div className="mb-6">
                <div className="flex items-center justify-between mb-2">
                  <label className="text-sm text-gray-400">Supply {asset.symbol}</label>
                  <span className="text-xs text-gray-500">Market Chrono Protocol</span>
                </div>
                <div className="relative">
                  <input
                    type="number"
                    value={supplyAmount}
                    onChange={(e) => handleSupplyChange(e.target.value)}
                    placeholder="0"
                    className="w-full bg-neutral-800 border border-neutral-700 rounded-lg px-4 py-3 text-white text-xl font-semibold focus:outline-none focus:border-neutral-600"
                  />
                  <div className="absolute right-3 top-1/2 -translate-y-1/2 flex items-center gap-2">
                    <div className="w-6 h-6 rounded-full bg-neutral-700 flex items-center justify-center text-xs text-white">
                      {asset.symbol.substring(0, 2)}
                    </div>
                    <span className="text-sm font-medium text-white">{asset.symbol}</span>
                  </div>
                </div>
                <div className="text-xs text-gray-500 mt-1">~ $0.00</div>
              </div>

              <div className="mb-6">
                <div className="flex items-center justify-between mb-2">
                  <label className="text-sm text-gray-400">Borrow USDC</label>
                  <span className="text-xs text-gray-500">Market Chrono Protocol</span>
                </div>
                <div className="relative">
                  <input
                    type="number"
                    value={borrowAmount}
                    onChange={(e) => handleBorrowChange(e.target.value)}
                    placeholder="0"
                    className="w-full bg-neutral-800 border border-neutral-700 rounded-lg px-4 py-3 text-white text-xl font-semibold focus:outline-none focus:border-neutral-600"
                  />
                  <div className="absolute right-3 top-1/2 -translate-y-1/2 flex items-center gap-2">
                    <div className="w-6 h-6 rounded-full bg-neutral-700 flex items-center justify-center text-xs text-white">
                      USD
                    </div>
                    <span className="text-sm font-medium text-white">USDC</span>
                  </div>
                </div>
                <div className="text-xs text-gray-500 mt-1">~ $0.00</div>
              </div>

              <div className="mb-6">
                <div className="flex items-center justify-between mb-2">
                  <label className="text-sm text-gray-400">LTV</label>
                  <span className="text-sm text-white font-medium">{ltvPercent.toFixed(2)}%</span>
                </div>
                <div className="relative">
                  <input
                    type="range"
                    min="0"
                    max="90"
                    step="0.1"
                    value={ltvPercent}
                    onChange={(e) => handleLtvChange(parseFloat(e.target.value))}
                    className="w-full h-2 bg-neutral-700 rounded-lg appearance-none cursor-pointer accent-[#c5ff4a]"
                    style={{
                      background: `linear-gradient(to right, #c5ff4a 0%, #c5ff4a ${(ltvPercent/90)*100}%, #404040 ${(ltvPercent/90)*100}%, #404040 100%)`
                    }}
                  />
                  <div className="flex justify-between text-xs text-gray-500 mt-1">
                    <span>0%</span>
                    <span className="text-[#c5ff4a]">Max: {maxLTV.toFixed(1)}%</span>
                    <span>90%</span>
                  </div>
                </div>
              </div>

              <div className="mb-6">
                <label className="text-sm text-gray-400 mb-2 block">Loan Duration</label>
                <div className="grid grid-cols-3 gap-2">
                  <div>
                    <input
                      type="number"
                      min="0"
                      value={timeDays}
                      onChange={(e) => setTimeDays(parseInt(e.target.value) || 0)}
                      placeholder="0"
                      className="w-full bg-neutral-800 border border-neutral-700 rounded-lg px-3 py-2 text-white text-center focus:outline-none focus:border-neutral-600"
                    />
                    <div className="text-xs text-gray-500 text-center mt-1">Days</div>
                  </div>
                  <div>
                    <input
                      type="number"
                      min="0"
                      max="23"
                      value={timeHours}
                      onChange={(e) => setTimeHours(Math.min(23, parseInt(e.target.value) || 0))}
                      placeholder="0"
                      className="w-full bg-neutral-800 border border-neutral-700 rounded-lg px-3 py-2 text-white text-center focus:outline-none focus:border-neutral-600"
                    />
                    <div className="text-xs text-gray-500 text-center mt-1">Hours</div>
                  </div>
                  <div>
                    <input
                      type="number"
                      min="0"
                      max="59"
                      value={timeMinutes}
                      onChange={(e) => setTimeMinutes(Math.min(59, parseInt(e.target.value) || 0))}
                      placeholder="0"
                      className="w-full bg-neutral-800 border border-neutral-700 rounded-lg px-3 py-2 text-white text-center focus:outline-none focus:border-neutral-600"
                    />
                    <div className="text-xs text-gray-500 text-center mt-1">Minutes</div>
                  </div>
                </div>
                <div className="text-xs text-gray-500 mt-2">
                  Total: {totalMinutes} minutes
                  {totalMinutes > 0 && (
                    <span className="ml-2">
                      (Max LTV: {maxLTV.toFixed(2)}%, LT: {currentLT.toFixed(2)}%)
                    </span>
                  )}
                </div>
              </div>

              <div className="space-y-3 mb-6 text-sm">
                <div className="flex justify-between">
                  <span className="text-gray-400">Net APY</span>
                  <span className="text-white font-medium">0.00%</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Oracle price</span>
                  <span className="text-white font-medium">$1.00</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Liquidation price</span>
                  <span className="text-white font-medium">-</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Your LTV (LLTV)</span>
                  <span className="text-white font-medium">
                    {ltvPercent > 0 ? `${ltvPercent.toFixed(2)}% / ${maxLTV.toFixed(2)}%` : '0%'}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Your health</span>
                  <span className="text-white font-medium">-</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Estimated gas fee</span>
                  <span className="text-white font-medium">0 ETH <span className="text-gray-500">$0</span></span>
                </div>
              </div>

              <button className="w-full bg-[#c5ff4a] hover:bg-[#b0e641] text-neutral-900 font-semibold py-3 rounded-lg transition-colors">
                Connect
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

