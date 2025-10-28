import { motion } from 'framer-motion'// eslint-disable-line no-unused-vars

export default function Navbar({ 
  activeView, 
  setActiveView, 
  isWalletConnected, 
  walletAddress,
  onConnect,
  onDisconnect 
}) {
  const navItems = [
    { id: 'lend', label: 'Lend' },
    { id: 'borrow', label: 'Borrow' },
    { id: 'pools', label: 'Pools' }
  ]

  return (
    <nav className="border-b border-neutral-800 bg-neutral-900 sticky top-0 z-50 backdrop-blur-sm bg-neutral-900/95">
      <div className="container mx-auto px-4">
        <div className="flex items-center h-16 gap-6">
          <span className="text-xl font-bold text-white">
            Chrono
          </span>

          <div className="flex items-center gap-1 relative">
            {navItems.map((item) => (
              <motion.button
                key={item.id}
                onClick={() => setActiveView(item.id)}
                className={`px-4 py-2 rounded-lg font-medium transition-all duration-200 relative ${
                  activeView === item.id
                    ? 'text-white'
                    : 'text-gray-400 hover:text-white'
                }`}
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
              >
                {activeView === item.id && (
                  <motion.div
                    layoutId="activeTab"
                    className="absolute inset-0 bg-neutral-800 rounded-lg"
                    style={{ zIndex: -1 }}
                    transition={{ type: "spring", stiffness: 300, damping: 30 }}
                  />
                )}
                {item.label}
              </motion.button>
            ))}
          </div>

          <div className="flex-1"></div>

          {isWalletConnected ? (
            <motion.div 
              className="flex items-center gap-3"
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
            >
              <div className="px-4 py-2 bg-neutral-800 border border-neutral-800 rounded-lg text-gray-300 text-sm font-medium">
                {walletAddress}
              </div>
              <motion.button
                onClick={onDisconnect}
                className="px-4 py-2 bg-neutral-800 border border-neutral-800 rounded-lg text-gray-400 hover:bg-neutral-700 hover:text-white transition-all duration-200 text-sm font-medium"
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
              >
                Disconnect
              </motion.button>
            </motion.div>
          ) : (
            <motion.button
              onClick={onConnect}
              className="px-6 py-2 bg-[#c5ff4a] hover:bg-[#b0e641] text-neutral-900 font-semibold rounded-lg transition-all duration-200"
              whileHover={{ scale: 1.05, boxShadow: "0 0 20px rgba(197, 255, 74, 0.3)" }}
              whileTap={{ scale: 0.95 }}
            >
              Connect
            </motion.button>
          )}
        </div>
      </div>
    </nav>
  )
}

