import { useState, useEffect } from 'react'
import Navbar from './components/Navbar'
import LendView from './components/LendView'
import BorrowView from './components/BorrowView'
import PoolsView from './components/PoolsView'
import WalletModal from './components/WalletModal'
import { connectWallet, disconnectWallet, configureFCL, subscribeToUser } from './utils/flowWallet'

function App() {
  const [activeView, setActiveView] = useState('lend')
  const [isWalletConnected, setIsWalletConnected] = useState(false)
  const [walletAddress, setWalletAddress] = useState('')
  const [isModalOpen, setIsModalOpen] = useState(false)

  useEffect(() => {
    configureFCL()

    const unsubscribe = subscribeToUser((user) => {
      if (user && user.loggedIn && user.addr) {
        setIsWalletConnected(true)
        setWalletAddress(formatAddress(user.addr))
      } else {
        setIsWalletConnected(false)
        setWalletAddress('')
      }
    })

    return () => {
      if (unsubscribe) unsubscribe()
    }
  }, [])

  const formatAddress = (address) => {
    if (!address) return ''
    return `${address.slice(0, 6)}...${address.slice(-4)}`
  }

  const handleConnect = () => {
    setIsModalOpen(true)
  }

  const handleConnectFlow = async () => {
    try {
      await connectWallet()
    } catch (error) {
      console.error('Failed to connect:', error)
      alert('Failed to connect wallet. Please try again.')
    }
  }

  const handleDisconnect = async () => {
    try {
      await disconnectWallet()
    } catch (error) {
      console.error('Failed to disconnect:', error)
    }
  }

  return (
    <div className="min-h-screen bg-neutral-950">
      <Navbar 
        activeView={activeView}
        setActiveView={setActiveView}
        isWalletConnected={isWalletConnected}
        walletAddress={walletAddress}
        onConnect={handleConnect}
        onDisconnect={handleDisconnect}
      />
      
      <main className="container mx-auto px-4 py-8">
        {activeView === 'lend' && <LendView />}
        {activeView === 'borrow' && <BorrowView />}
        {activeView === 'pools' && <PoolsView />}
      </main>

      <WalletModal 
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        onConnectFlow={handleConnectFlow}
      />
    </div>
  )
}

export default App
