import { useState } from 'react'
import { motion } from 'framer-motion'// eslint-disable-line no-unused-vars
import IRMGraph from './IRMGraph'

export default function LendPositionView({ asset, onBack }) {
  const [supplyAmount, setSupplyAmount] = useState('')

  // Mock data - will be replaced with real data
  const vaultData = {
    totalSupply: '$38.57M',
    totalSupplyTokens: '9,268.38 WETH',
    supplyAPY: '1.24%',
    utilization: '62.67%',
    totalBorrowed: '$24.17M',
    availableLiquidity: '$14.40M',
    borrowAPY: '1.98%',
    oraclePrice: '$4,161.18',
    market: 'Euler Prime',
    vaultType: 'Governed',
    canBeBorrowed: 19,
    canBeUsedAsCollateral: 23,
    liquidationPenalty: '0-15%',
    supplyCap: '$312.09M',
    supplyCapPercent: '12.35%',
    borrowCap: '$280.88M',
    borrowCapPercent: '8.60%',
    shareTokenRate: '1.023956',
    badDebtSocialization: 'Yes',
    interestFee: '0%'
  }

  return (
    <motion.div 
      className="min-h-screen bg-neutral-950 pt-8"
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -20 }}
      transition={{ duration: 0.3, ease: [0.4, 0, 0.2, 1] }}
    >
      <div className="container mx-auto px-4">
        <motion.button 
          onClick={onBack}
          className="mb-6 text-gray-400 hover:text-white flex items-center gap-2 transition-colors"
          whileHover={{ x: -4 }}
          whileTap={{ scale: 0.95 }}
        >
          <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
          Back to Lend
        </motion.button>

        <motion.div 
          className="mb-8"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.4, delay: 0.1 }}
        >
          <div className="flex items-center gap-3 mb-4">
            <div className="w-16 h-16 rounded-full bg-neutral-800 border-2 border-neutral-950 flex items-center justify-center text-white font-bold text-xl">
              {asset.symbol.substring(0, 1)}
            </div>
            <div>
              <div className="text-xs text-gray-500">Euler Prime</div>
              <h1 className="text-4xl font-bold text-white">{asset.symbol}</h1>
            </div>
          </div>

          <div className="grid grid-cols-3 gap-8">
            <div>
              <div className="text-gray-500 text-sm mb-1">Total supply</div>
              <div className="text-3xl font-bold text-white">{vaultData.totalSupply}</div>
              <div className="text-xs text-gray-500">{vaultData.totalSupplyTokens}</div>
            </div>
            <div>
              <div className="text-gray-500 text-sm mb-1">Supply APY</div>
              <div className="text-3xl font-bold text-white">{vaultData.supplyAPY}</div>
            </div>
            <div>
              <div className="text-gray-500 text-sm mb-1">Utilization</div>
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-full border-4 border-[#c5ff4a] border-t-transparent rotate-45"></div>
                <div className="text-3xl font-bold text-white">{vaultData.utilization}</div>
              </div>
            </div>
          </div>
        </motion.div>

        <div className="grid grid-cols-3 gap-6">
          <div className="col-span-2 space-y-6">
            <motion.div 
              className="bg-neutral-900 border border-neutral-800 rounded-xl p-6"
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.4, delay: 0.2 }}
            >
              <h3 className="text-xl font-bold text-white mb-6">Overview</h3>
              <div className="grid grid-cols-3 gap-6">
                <div>
                  <div className="text-xs text-gray-500 mb-2">Oracle price</div>
                  <div className="text-lg font-semibold text-white">{vaultData.oraclePrice}</div>
                  <div className="flex items-center gap-1 mt-1">
                    <div className="w-4 h-4 rounded-full bg-blue-600"></div>
                  </div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 mb-2">Market</div>
                  <div className="text-lg font-semibold text-white">{vaultData.market}</div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 mb-2">Risk curator</div>
                  <div className="flex items-center gap-2">
                    <div className="w-5 h-5 rounded-full bg-neutral-700"></div>
                    <div className="w-5 h-5 rounded-full bg-purple-600"></div>
                  </div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 mb-2">Vault type</div>
                  <div className="flex items-center gap-2">
                    <div className="w-4 h-4 bg-[#c5ff4a] rounded"></div>
                    <span className="text-sm font-medium text-white">{vaultData.vaultType}</span>
                  </div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 mb-2">Can be borrowed</div>
                  <div className="flex items-center gap-2">
                    <svg className="w-4 h-4 text-[#c5ff4a]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                    </svg>
                    <span className="text-sm font-medium text-white">Yes by {vaultData.canBeBorrowed} vaults</span>
                  </div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 mb-2">Can be used as collateral</div>
                  <div className="flex items-center gap-2">
                    <svg className="w-4 h-4 text-[#c5ff4a]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                    </svg>
                    <span className="text-sm font-medium text-white">Yes by {vaultData.canBeUsedAsCollateral} vaults</span>
                  </div>
                </div>
              </div>
            </motion.div>

            <motion.div 
              className="bg-neutral-900 border border-neutral-800 rounded-xl p-6"
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.4, delay: 0.3 }}
            >
              <h3 className="text-xl font-bold text-white mb-6">Statistics</h3>
              <div className="grid grid-cols-3 gap-6">
                <div>
                  <div className="text-xs text-gray-500 mb-2">Total supply</div>
                  <div className="text-xl font-bold text-white">{vaultData.totalSupply}</div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 mb-2">Total borrowed</div>
                  <div className="text-xl font-bold text-white">{vaultData.totalBorrowed}</div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 mb-2">Available liquidity</div>
                  <div className="text-xl font-bold text-white">{vaultData.availableLiquidity}</div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 mb-2">Supply APY</div>
                  <div className="text-xl font-bold text-white">{vaultData.supplyAPY}</div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 mb-2">Borrow APY</div>
                  <div className="text-xl font-bold text-white">{vaultData.borrowAPY}</div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 mb-2">Utilization</div>
                  <div className="flex items-center gap-2">
                    <div className="w-8 h-8 rounded-full border-3 border-[#c5ff4a] border-t-transparent"></div>
                    <div className="text-xl font-bold text-white">{vaultData.utilization}</div>
                  </div>
                </div>
              </div>
            </motion.div>

            <motion.div 
              className="bg-neutral-900 border border-neutral-800 rounded-xl p-6"
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.4, delay: 0.4 }}
            >
              <div className="flex items-center gap-2 mb-4">
                <h3 className="text-xl font-bold text-white">Interest rate model</h3>
                <span className="px-2 py-0.5 bg-[#c5ff4a] text-neutral-900 text-xs font-semibold rounded">Kink</span>
              </div>
              <IRMGraph currentUtilization={parseFloat(vaultData.utilization)} />
            </motion.div>

            <div className="bg-neutral-900 border border-neutral-800 rounded-xl p-6">
              <h3 className="text-xl font-bold text-white mb-6">Risk parameters</h3>
              <div className="grid grid-cols-3 gap-6">
                <div>
                  <div className="text-xs text-gray-500 mb-2">Liquidation penalty</div>
                  <div className="text-base font-semibold text-white">Dynamic range {vaultData.liquidationPenalty}</div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 mb-2">Supply cap</div>
                  <div className="flex items-center gap-2">
                    <div className="w-10 h-10 rounded-full border-3 border-gray-600 relative">
                      <div className="absolute inset-0 rounded-full border-3 border-[#c5ff4a] border-t-transparent" style={{clipPath: `polygon(0 0, 100% 0, 100% ${vaultData.supplyCapPercent}, 0 ${vaultData.supplyCapPercent})`}}></div>
                    </div>
                    <div>
                      <div className="text-base font-semibold text-white">{vaultData.supplyCap}</div>
                      <div className="text-xs text-gray-500">{vaultData.supplyCapPercent}</div>
                    </div>
                  </div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 mb-2">Borrow cap</div>
                  <div className="flex items-center gap-2">
                    <div className="w-10 h-10 rounded-full border-3 border-gray-600 relative">
                      <div className="absolute inset-0 rounded-full border-3 border-[#c5ff4a] border-t-transparent" style={{clipPath: `polygon(0 0, 100% 0, 100% ${vaultData.borrowCapPercent}, 0 ${vaultData.borrowCapPercent})`}}></div>
                    </div>
                    <div>
                      <div className="text-base font-semibold text-white">{vaultData.borrowCap}</div>
                      <div className="text-xs text-gray-500">{vaultData.borrowCapPercent}</div>
                    </div>
                  </div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 mb-2">Share token exchange rate</div>
                  <div className="text-base font-semibold text-white">{vaultData.shareTokenRate}</div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 mb-2">Bad debt socialisation</div>
                  <div className="text-base font-semibold text-white">{vaultData.badDebtSocialization}</div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 mb-2">Interest fee</div>
                  <div className="text-base font-semibold text-white">{vaultData.interestFee}</div>
                </div>
              </div>
            </div>

            <div className="bg-neutral-900 border border-neutral-800 rounded-xl p-6">
              <h3 className="text-xl font-bold text-white mb-4">Vault exposure</h3>
              <p className="text-gray-400 text-sm mb-4">This vault can be both borrowed and used as collateral by other vaults.</p>
              
              <div className="flex gap-4 mb-6">
                <button className="px-4 py-2 bg-white text-neutral-900 rounded-lg text-sm font-semibold flex items-center gap-2">
                  Can be borrowed <span className="bg-neutral-800 text-white px-2 py-0.5 rounded">19</span>
                </button>
                <button className="px-4 py-2 bg-neutral-800 text-gray-400 rounded-lg text-sm font-medium flex items-center gap-2 hover:bg-neutral-700">
                  Can be used as collateral <span className="bg-neutral-700 text-white px-2 py-0.5 rounded">23</span>
                </button>
              </div>

              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="border-b border-neutral-800 text-xs text-gray-500">
                      <th className="text-left p-3">Collateral</th>
                      <th className="text-left p-3">Max LTV</th>
                      <th className="text-left p-3">LLTV</th>
                      <th className="text-left p-3">Adapter price</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr className="border-b border-neutral-800 hover:bg-neutral-800/50">
                      <td className="p-3">
                        <div className="flex items-center gap-2">
                          <div className="w-6 h-6 rounded-full bg-blue-600 flex items-center justify-center text-white text-xs">W</div>
                          <div>
                            <div className="text-sm font-medium text-white">WSTETH</div>
                            <div className="text-xs text-gray-500">Ungoverned 001</div>
                          </div>
                        </div>
                      </td>
                      <td className="p-3 text-white font-medium">93.00%</td>
                      <td className="p-3 text-white font-medium">95.00%</td>
                      <td className="p-3">
                        <div className="text-white font-medium">$5,066.69</div>
                        <div className="flex items-center gap-1 mt-1">
                          <div className="w-3 h-3 rounded-full bg-red-500"></div>
                          <div className="w-3 h-3 rounded-full bg-blue-500"></div>
                        </div>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>

            <div className="bg-neutral-900 border border-neutral-800 rounded-xl p-6">
              <h3 className="text-xl font-bold text-white mb-6">Addresses</h3>
              <div className="grid grid-cols-3 gap-6">
                <div>
                  <div className="text-xs text-gray-500 mb-2">Underlying {asset.symbol} token</div>
                  <div className="flex items-center gap-2">
                    <span className="text-[#c5ff4a] font-mono text-sm">0xC02a...6Cc2</span>
                    <button className="text-gray-400 hover:text-white">
                      <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                      </svg>
                    </button>
                  </div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 mb-2">{asset.symbol} vault</div>
                  <div className="flex items-center gap-2">
                    <span className="text-[#c5ff4a] font-mono text-sm">0xD8b2...84C2</span>
                    <button className="text-gray-400 hover:text-white">
                      <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                      </svg>
                    </button>
                  </div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 mb-2">{asset.symbol} debt</div>
                  <div className="flex items-center gap-2">
                    <span className="text-[#c5ff4a] font-mono text-sm">0xb005...473A</span>
                    <button className="text-gray-400 hover:text-white">
                      <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                      </svg>
                    </button>
                  </div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 mb-2">Risk curator</div>
                  <div className="flex items-center gap-2">
                    <span className="text-[#c5ff4a] font-mono text-sm">0x3540...0a1b</span>
                    <button className="text-gray-400 hover:text-white">
                      <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                      </svg>
                    </button>
                  </div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 mb-2">Fee receiver</div>
                  <div className="flex items-center gap-2">
                    <span className="text-[#c5ff4a] font-mono text-sm">0x0000...0000</span>
                    <button className="text-gray-400 hover:text-white">
                      <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                      </svg>
                    </button>
                  </div>
                </div>
                <div>
                  <div className="text-xs text-gray-500 mb-2">Oracle router address</div>
                  <div className="flex items-center gap-2">
                    <span className="text-[#c5ff4a] font-mono text-sm">0x83B3...7136</span>
                    <button className="text-gray-400 hover:text-white">
                      <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                      </svg>
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div className="sticky top-8 h-fit">
            <div className="bg-neutral-900 border border-neutral-800 rounded-xl p-6">
              <h3 className="text-lg font-semibold text-white mb-6">Supply {asset.symbol}</h3>

              <div className="mb-6">
                <div className="relative">
                  <input
                    type="number"
                    value={supplyAmount}
                    onChange={(e) => setSupplyAmount(e.target.value)}
                    placeholder="0"
                    className="w-full bg-neutral-800 border border-neutral-700 rounded-lg px-4 py-4 text-white text-2xl font-bold focus:outline-none focus:border-neutral-600"
                  />
                  <div className="absolute right-3 top-1/2 -translate-y-1/2 flex items-center gap-2">
                    <span className="text-sm font-medium text-gray-400">~ $0.00</span>
                  </div>
                </div>
              </div>

              <div className="space-y-3 mb-6 text-sm">
                <div className="flex justify-between">
                  <span className="text-gray-400">Supply APY</span>
                  <span className="text-white font-medium">{vaultData.supplyAPY}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-400">Deposit value</span>
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
    </motion.div>
  )
}

