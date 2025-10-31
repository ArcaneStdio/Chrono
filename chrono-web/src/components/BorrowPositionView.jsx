import { useState, useEffect } from 'react'

import { motion } from 'framer-motion'// eslint-disable-line no-unused-vars

import { InfoIcon } from './Icons'  

import LTVGraph from './LTVGraph'  

import LTGraph from './LTGraph'  

import { createBorrowingPosition } from '../utils/borrow-transaction-eth'
import * as fcl from '@onflow/fcl'


export default function BorrowPositionView({
  asset,
  onBack,
  // New Props for Wallet Connection
  isWalletConnected,
  onConnect,
  userAddress
}) {

  const [activeTab, setActiveTab] = useState('pair')
  const [borrowAmount, setBorrowAmount] = useState('')
  const [supplyAmount, setSupplyAmount] = useState('')
  const [ltvPercent, setLtvPercent] = useState(0)
  const [timeMinutes, setTimeMinutes] = useState(0)
  const [timeHours, setTimeHours] = useState(0)
  const [timeDays, setTimeDays] = useState(0)
  const [userSupply, setUserSupply] = useState({ ETH: 0, FLOW: 0, USDC: 0 })
  const [maxSupplyAmount, setMaxSupplyAmount] = useState(0)
  const [isLoadingSupply, setIsLoadingSupply] = useState(false)
  const [ethPrice, setEthPrice] = useState(0) // Store ETH price for USDC conversion

  const getTokenKeyFromSymbol = (symbol) => {
    const symbolMap = {
      'WETH': 'ETH',
      'ETH': 'ETH',
      'FLOW': 'FLOW',
      'USDC': 'USDC'
    }
    return symbolMap[symbol] || symbol
  }

  const getCollateralToken = () => {
    if (!asset || !asset.symbol) {
      return 'WETH'
    }
    return asset.symbol
  }

  const getBorrowToken = () => {
    if (!asset || !asset.symbol) {
      return 'USDC' 
    }
    if (asset.symbol === 'WETH' || asset.symbol === 'ETH') {
      return 'USDC'
    }
    if (asset.symbol === 'USDC') {
      return 'WETH'
    }
    return 'USDC' 
  }

  const collateralSymbol = getCollateralToken()
  const borrowTokenSymbol = getBorrowToken()

  useEffect(() => {
    const fetchVaultData = async () => {
      if (!asset || (asset.symbol !== 'WETH' && asset.symbol !== 'ETH')) return
      
      try {
        const response = await fetch('http://localhost:3001/api/vault/data')
        const data = await response.json()
        
        if (data && data.vaults) {
          const ethVault = data.vaults.find(v => v.symbol === 'ETH' || v.symbol === 'WETH')
          if (ethVault && ethVault.price) {
            setEthPrice(parseFloat(ethVault.price))
          }
        }
      } catch (error) {
        console.error('Failed to fetch vault data for ETH price:', error)
      }
    }

    fetchVaultData()
  }, [asset?.symbol])

  useEffect(() => {
    const fetchUserSupply = async () => {
      if (!isWalletConnected || !asset) return
      
      try {
        setIsLoadingSupply(true)
        const user = await fcl.currentUser.snapshot()
        const flowAddress = user?.addr
        
        if (!flowAddress) {
          console.warn('No Flow address found')
          return
        }

        const response = await fetch(`http://localhost:3001/api/user/supply/${flowAddress}`)
        const result = await response.json()
        
        if (result.success && result.data) {
          setUserSupply({
            ETH: parseFloat(result.data.ETH || 0),
            FLOW: parseFloat(result.data.FLOW || 0),
            USDC: parseFloat(result.data.USDC || 0)
          })
          
          const collateralTokenKey = getTokenKeyFromSymbol(collateralSymbol)
          const maxSupply = parseFloat(result.data[collateralTokenKey] || 0)
          setMaxSupplyAmount(maxSupply)
          
          if (parseFloat(supplyAmount) > maxSupply) {
            setSupplyAmount(maxSupply > 0 ? maxSupply.toString() : '')
          }
        }
      } catch (error) {
        console.error('Failed to fetch user supply:', error)
      } finally {
        setIsLoadingSupply(false)
      }
    }

    fetchUserSupply()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isWalletConnected, asset?.symbol])

  const totalMinutes = timeDays * 24 * 60 + timeHours * 60 + timeMinutes

  const calculateMaxLTV = (t) => {
    if (t === 0) return 90
    return Math.min(90, 75 + 15 * Math.exp(-0.000333 * t))
  }

  const calculateLT = (t) => {
    return 77 + 18 * Math.exp(-0.000333 * t)
  }

  const maxLTV = calculateMaxLTV(totalMinutes)
  const currentLT = calculateLT(totalMinutes)

  const getCollateralValueInBorrowToken = (collateralAmount) => {
    if ((asset?.symbol === 'WETH' || asset?.symbol === 'ETH') && ethPrice > 0) {
      return collateralAmount * ethPrice
    }
    return collateralAmount
  }

  const handleSupplyChange = (value) => {
    const numValue = parseFloat(value) || 0
    const cappedValue = maxSupplyAmount > 0 ? Math.min(numValue, maxSupplyAmount) : numValue
    const valueToSet = isNaN(cappedValue) ? '' : cappedValue.toString()
    
    setSupplyAmount(valueToSet)
    if (valueToSet && ltvPercent > 0) {
      const collateralValueInBorrowToken = getCollateralValueInBorrowToken(parseFloat(valueToSet))
      const calculatedBorrow = (collateralValueInBorrowToken * ltvPercent) / 100
      setBorrowAmount(calculatedBorrow.toFixed(6))
    } else {
      setBorrowAmount('')
    }
  }

  const handleLtvChange = (value) => {
    const cappedLtv = Math.min(value, maxLTV)
    setLtvPercent(cappedLtv)
    if (supplyAmount) {
      const collateralValueInBorrowToken = getCollateralValueInBorrowToken(parseFloat(supplyAmount))
      const calculatedBorrow = (collateralValueInBorrowToken * cappedLtv) / 100
      setBorrowAmount(calculatedBorrow.toFixed(6))
    }
  }

  const handleBorrowChange = (value) => {
    setBorrowAmount(value)
    if (supplyAmount && parseFloat(supplyAmount) > 0) {
      const collateralValueInBorrowToken = getCollateralValueInBorrowToken(parseFloat(supplyAmount))
      const calculatedLtv = (parseFloat(value) / collateralValueInBorrowToken) * 100
      setLtvPercent(Math.min(calculatedLtv, maxLTV))
    }
  }

  useEffect(() => {
    if (ltvPercent > maxLTV) {
      handleLtvChange(maxLTV)
    }
  }, [totalMinutes])


  // --- New Borrow Transaction Logic ---
  const handleBorrow = async () => {
    const collateralAmountFloat = parseFloat(supplyAmount)
    const borrowAmountFloat = parseFloat(borrowAmount)
    const duration = totalMinutes

    if (isNaN(collateralAmountFloat) || isNaN(borrowAmountFloat) || isNaN(duration)) {
      console.error('Invalid input: All amounts must be valid numbers')
      alert('Please enter valid numbers for collateral, borrow amount, and duration')
      return
    }

    if (collateralAmountFloat <= 0 || borrowAmountFloat <= 0 || duration <= 0) {
      console.error('Supply, Borrow amounts, and Duration must be greater than 0 to create a position.')
      alert('All values must be greater than 0')
      return
    }

    if (maxSupplyAmount > 0 && collateralAmountFloat > maxSupplyAmount) {
      console.error(`Collateral amount ${collateralAmountFloat} exceeds max supply ${maxSupplyAmount}`)
      alert(`Collateral amount cannot exceed your supplied amount: ${maxSupplyAmount.toFixed(8)} ${asset.symbol}`)
      return
    }

    // Check for UFix64 overflow (max value is 184467440737.09551615)
    const MAX_UFIX64 = 184467440737.09551615
    if (collateralAmountFloat > MAX_UFIX64) {
      alert(`Collateral amount too large. Maximum: ${MAX_UFIX64}`)
      return
    }
    if (borrowAmountFloat > MAX_UFIX64) {
      alert(`Borrow amount too large. Maximum: ${MAX_UFIX64}`)
      return
    }

    // Check for UInt64 overflow (max value is 18446744073709551615)
    const MAX_UINT64 = 18446744073709551615
    if (duration > MAX_UINT64) {
      alert(`Duration too large. Maximum: ${MAX_UINT64} minutes`)
      return
    }

    // The contract's LTV formula: a + b*2^(c*t) where c=-1, t=duration
    // With c=-1, it calculates: 2^duration and converts to UFix64
    // UFix64 max is ~184 billion, so 2^n must be < 184,467,440,737
    // This means n <= 37, so duration <= 37 minutes for safety
    const MAX_SAFE_MINUTES = 37 
    if (duration > MAX_SAFE_MINUTES) {
      alert(`Duration too large!\n\nYou entered: ${duration} minutes\n\nMaximum allowed: ${MAX_SAFE_MINUTES} minutes\n\nIMPORTANT: This is a temporary limit due to the contract's LTV formula (ltvFormulaC=-1).\nThe contract needs to be updated with a safer formula to allow longer durations.`)
      return
    }
    
    if (duration < 1) {
      alert('Duration must be at least 1 minute')
      return
    }

    console.log('Creating borrow position with:', {
      collateral: collateralAmountFloat,
      borrow: borrowAmountFloat,
      duration: duration,
      durationDays: (duration / (24 * 60)).toFixed(2),
      collateralFormatted: collateralAmountFloat.toFixed(8),
      borrowFormatted: borrowAmountFloat.toFixed(8),
      currentLTV: ((borrowAmountFloat / collateralAmountFloat) * 100).toFixed(2) + '%',
      maxLTV: maxLTV.toFixed(2) + '%'
    })

    try {
      const txId = await createBorrowingPosition(
        collateralAmountFloat.toFixed(8), 
        borrowAmountFloat.toFixed(8),    
        duration.toString()               
      )
      console.log('Borrowing Transaction Sent. ID:', txId)
      alert(`Success! Borrow position created. Transaction ID: ${txId}`)
      // Handle success feedback here
    } catch (error) {
      console.error('Failed to send Borrowing Transaction:', error)
      alert(`Transaction failed: ${error.message}`)
      // Handle error feedback here
    }
  }

  // Conditional button logic
  const isReadyForTransaction = 
    !isNaN(parseFloat(supplyAmount)) && parseFloat(supplyAmount) > 0 && 
    !isNaN(parseFloat(borrowAmount)) && parseFloat(borrowAmount) > 0 && 
    totalMinutes > 0

  const buttonText = isWalletConnected
    ? (isReadyForTransaction ? 'Create Borrow Position' : 'Enter Amounts')
    : 'Connect Wallet'

  const handleButtonClick = async () => {
    if (!isWalletConnected) {
      await onConnect()
      return
    }

    if (!isReadyForTransaction) return
    await handleBorrow()
  }

  const buttonDisabled = isWalletConnected && !isReadyForTransaction  
  // --- End New Borrow Transaction Logic ---


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
          Back to Borrow
        </motion.button>

        <motion.div
          className="mb-6 md:mb-8"
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.4, delay: 0.1 }}
        >
          <div className="flex items-center gap-3 mb-4">
            <div className="flex items-center flex-shrink-0">
              <div className="w-10 h-10 md:w-12 md:h-12 rounded-full bg-neutral-800 border-2 border-neutral-950 flex items-center justify-center text-white font-semibold text-sm md:text-base">
                {asset.symbol.substring(0, 2)}
              </div>
              <div className="w-10 h-10 md:w-12 md:h-12 rounded-full bg-neutral-800 border-2 border-neutral-950 flex items-center justify-center -ml-3 md:-ml-4 text-white font-semibold text-sm md:text-base">
                USD
              </div>
            </div>
            <div>
              <div className="text-xs text-gray-500">Chrono Protocol</div>
              <h1 className="text-xl md:text-3xl font-bold text-white">{asset.name} / USDC</h1>
            </div>
          </div>

          <div className="grid grid-cols-3 gap-3 md:gap-8">
            <div>
              <div className="text-gray-500 text-xs md:text-sm mb-1">Liquidity</div>
              <div className="text-base md:text-2xl font-bold text-white">{asset.available}</div>
              <div className="text-xs text-gray-500 hidden md:block">{asset.availableToken}</div>
            </div>
            <div>
              <div className="text-gray-500 text-xs md:text-sm mb-1">Max multiplier</div>
              <div className="text-base md:text-2xl font-bold text-white">16.65 x</div>
            </div>
            <div>
              <div className="text-gray-500 text-xs md:text-sm mb-1">Max ROE</div>
              <div className="text-base md:text-2xl font-bold text-[#c5ff4a]">{maxLTV.toFixed(2)} %</div>
            </div>
          </div>
        </motion.div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2 space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 md:gap-6">
              <motion.div
                className="bg-neutral-900 border border-neutral-800 rounded-xl p-6"
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.4, delay: 0.2 }}
              >
                <h3 className="text-lg font-semibold text-white mb-4">Loan-to-Value (LTV) Over Time</h3>
                <LTVGraph currentTime={totalMinutes} />
              </motion.div>
              <motion.div
                className="bg-neutral-900 border border-neutral-800 rounded-xl p-6"
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.4, delay: 0.25 }}
              >
                <h3 className="text-lg font-semibold text-white mb-4">Liquidation Threshold (LT) Over Time</h3>
                <LTGraph currentTime={totalMinutes} />
              </motion.div>
            </div>

            <div className="border-b border-neutral-800 mb-6">
              <div className="flex gap-6">
                <button
                  onClick={() => setActiveTab('pair')}
                  className={`pb-3 px-1 text-sm font-medium transition-colors relative ${activeTab === 'pair' ? 'text-white' : 'text-gray-500 hover:text-gray-300'
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
                  className={`pb-3 px-1 text-sm font-medium transition-colors relative ${activeTab === 'collateral' ? 'text-white' : 'text-gray-500 hover:text-gray-300'
                    }`}
                >
                  <div className="flex items-center gap-2">
                    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    Collateral {collateralSymbol}
                  </div>
                  {activeTab === 'collateral' && (
                    <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-[#c5ff4a]"></div>
                  )}
                </button>
                <button
                  onClick={() => setActiveTab('debt')}
                  className={`pb-3 px-1 text-sm font-medium transition-colors relative ${activeTab === 'debt' ? 'text-white' : 'text-gray-500 hover:text-gray-300'
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

            <div className="bg-neutral-900 border border-neutral-800 rounded-xl p-4 md:p-6">
              {activeTab === 'pair' && (
                <div>
                  <h3 className="text-lg md:text-xl font-bold text-white mb-4 md:mb-6">Overview</h3>
                  <div className="grid grid-cols-2 md:grid-cols-3 gap-4 md:gap-6">
                    <div>
                      <div className="text-xs text-gray-500 mb-2">Oracle price</div>
                      <div className="text-lg font-semibold text-white">$1.00</div>
                      <div className="text-xs text-gray-500">{asset.symbol} ⇄</div>
                    </div>
                    <div>
                      <div className="text-xs text-gray-500 mb-2">Supply APY</div>
                      <div className="text-lg font-semibold text-[#c5ff4a]">{asset.supplyAPY}</div>
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

          <div className="lg:sticky lg:top-8 h-fit">
            <div className="bg-neutral-900 border border-neutral-800 rounded-xl p-4 md:p-6">
              <div className="border-b border-neutral-800 mb-6">
                <button className="pb-3 px-1 text-sm font-medium text-white relative">
                  Borrow
                  <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-[#c5ff4a]"></div>
                </button>
              </div>

              <div className="mb-6">
                <div className="flex items-center justify-between mb-2">
                  <label className="text-sm text-gray-400">
                    Supply {collateralSymbol} {asset.symbol === 'USDC' && '(Collateral)'}
                  </label>
                  <span className="text-xs text-gray-500">Market Chrono Protocol</span>
                </div>
                <div className="relative">
                  <input
                    type="number"
                    min="0"
                    max={maxSupplyAmount > 0 ? maxSupplyAmount : undefined}
                    value={supplyAmount}
                    onChange={(e) => handleSupplyChange(e.target.value)}
                    placeholder="0"
                    className="w-full bg-neutral-800 border border-neutral-700 rounded-lg px-4 py-3 text-white text-xl font-semibold focus:outline-none focus:border-neutral-600"
                  />
                  <div className="absolute right-3 top-1/2 -translate-y-1/2 flex items-center gap-2">
                    <div className="w-6 h-6 rounded-full bg-neutral-700 flex items-center justify-center text-xs text-white">
                      {collateralSymbol.substring(0, 2)}
                    </div>
                    <span className="text-sm font-medium text-white">{collateralSymbol}</span>
                  </div>
                </div>
                <div className="flex flex-col gap-1 mt-1">
                  <div className="flex justify-between items-center text-xs text-gray-500">
                    {isLoadingSupply ? (
                      <span>Loading your supply...</span>
                    ) : maxSupplyAmount > 0 ? (
                      <>
                        <span>Max available: {maxSupplyAmount.toFixed(8)} {collateralSymbol}</span>
                        {(asset.symbol === 'WETH' || asset.symbol === 'ETH') && ethPrice > 0 && (
                          <span className="text-gray-400">
                            ≈ {(maxSupplyAmount * ethPrice).toFixed(2)} USDC value
                          </span>
                        )}
                      </>
                    ) : isWalletConnected ? (
                      <span>No {collateralSymbol} supplied</span>
                    ) : (
                      <span>Connect wallet to see your available collateral</span>
                    )}
                    {maxSupplyAmount > 0 && (
                      <button
                        onClick={() => {
                          setSupplyAmount(maxSupplyAmount.toString())
                          if (ltvPercent > 0) {
                            const collateralValueInBorrowToken = getCollateralValueInBorrowToken(maxSupplyAmount)
                            const calculatedBorrow = (collateralValueInBorrowToken * ltvPercent) / 100
                            setBorrowAmount(calculatedBorrow.toFixed(6))
                          }
                        }}
                        className="text-[#c5ff4a] hover:text-[#b0e641] transition-colors font-medium"
                      >
                        Max
                      </button>
                    )}
                  </div>
                </div>
              </div>

              <div className="mb-6">
                <div className="flex items-center justify-between mb-2">
                  <label className="text-sm text-gray-400">
                    Borrow {borrowTokenSymbol}
                  </label>
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
                      {borrowTokenSymbol.substring(0, 2)}
                    </div>
                    <span className="text-sm font-medium text-white">
                      {borrowTokenSymbol}
                    </span>
                  </div>
                </div>
                <div className="text-xs text-gray-500 mt-1"></div>
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
                      background: `linear-gradient(to right, #c5ff4a 0%, #c5ff4a ${(ltvPercent / 90) * 100}%, #404040 ${(ltvPercent / 90) * 100}%, #404040 100%)`
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
                <div className="flex items-center justify-between mb-2">
                  <label className="text-sm text-gray-400">Loan Duration</label>
                  <span className="text-xs text-red-400 font-semibold">Max: 37 minutes</span>
                </div>
                <div className="bg-orange-900/20 border border-orange-700/50 rounded-lg p-3 mb-3">
                  <p className="text-xs text-orange-300">
                    <strong>Temporary Limitation:</strong> Due to the contract's current LTV formula, loans are limited to <strong>37 minutes maximum</strong>. 
                    Longer durations cause arithmetic overflow. The contract needs to be updated with an improved formula.
                  </p>
                </div>
                <div className="grid grid-cols-3 gap-2">
                  <div>
                    <input
                      type="number"
                      min="0"
                      max="0"
                      value={timeDays}
                      onChange={(e) => setTimeDays(0)}
                      placeholder="0"
                      disabled
                      className="w-full bg-neutral-800 border border-neutral-700 rounded-lg px-3 py-2 text-gray-600 text-center focus:outline-none cursor-not-allowed"
                    />
                    <div className="text-xs text-gray-500 text-center mt-1">Days (disabled)</div>
                  </div>
                  <div>
                    <input
                      type="number"
                      min="0"
                      max="0"
                      value={timeHours}
                      onChange={(e) => setTimeHours(0)}
                      placeholder="0"
                      disabled
                      className="w-full bg-neutral-800 border border-neutral-700 rounded-lg px-3 py-2 text-gray-600 text-center focus:outline-none cursor-not-allowed"
                    />
                    <div className="text-xs text-gray-500 text-center mt-1">Hours (disabled)</div>
                  </div>
                  <div>
                    <input
                      type="number"
                      min="1"
                      max="37"
                      value={timeMinutes}
                      onChange={(e) => setTimeMinutes(Math.min(37, Math.max(1, parseInt(e.target.value) || 1)))}
                      placeholder="1-37"
                      className="w-full bg-neutral-800 border border-neutral-700 rounded-lg px-3 py-2 text-white text-center focus:outline-none focus:border-neutral-600"
                    />
                    <div className="text-xs text-gray-500 text-center mt-1">Minutes (1-37)</div>
                  </div>
                </div>
                <div className={`text-xs mt-2 ${totalMinutes > 37 ? 'text-red-400 font-semibold' : 'text-gray-400'}`}>
                  Total: {totalMinutes} minute{totalMinutes !== 1 ? 's' : ''}
                  {totalMinutes > 37 && (
                    <span className="ml-2">Exceeds 37 minute limit!</span>
                  )}
                  {totalMinutes > 0 && totalMinutes <= 37 && (
                    <span className="ml-2 text-gray-500">
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

              {/* Updated Conditional Button */}
              <button
                onClick={handleButtonClick}
                className={`w-full font-semibold py-3 rounded-lg transition-colors ${isWalletConnected && isReadyForTransaction
                    ? 'bg-[#c5ff4a] hover:bg-[#b0e641] text-neutral-900'
                    : 'bg-neutral-700 text-gray-400 cursor-not-allowed'
                  }`}
              >
                {buttonText}
              </button>
              {/* Display user address if connected */}
              {isWalletConnected && userAddress && (
                <p className="text-xs text-gray-500 mt-2 text-center truncate">
                  Connected as: {userAddress}
                </p>
              )}
            </div>
          </div>
        </div>
      </div>
    </motion.div>
  )

}