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
    <nav className="border-b border-neutral-800 bg-neutral-900">
      <div className="container mx-auto px-4">
        <div className="flex items-center h-16 gap-6">
          <span className="text-xl font-bold text-white">
            Chrono
          </span>

          <div className="flex items-center gap-1">
            {navItems.map((item) => (
              <button
                key={item.id}
                onClick={() => setActiveView(item.id)}
                className={`px-4 py-2 rounded-lg font-medium transition-all duration-200 ${
                  activeView === item.id
                    ? 'bg-neutral-800 text-white'
                    : 'text-gray-400 hover:text-white hover:bg-neutral-800'
                }`}
              >
                {item.label}
              </button>
            ))}
          </div>

          <div className="flex-1"></div>

          {isWalletConnected ? (
            <div className="flex items-center gap-3">
              <div className="px-4 py-2 bg-neutral-800 border border-neutral-800 rounded-lg text-gray-300 text-sm font-medium">
                {walletAddress}
              </div>
              <button
                onClick={onDisconnect}
                className="px-4 py-2 bg-neutral-800 border border-neutral-800 rounded-lg text-gray-400 hover:bg-neutral-700 hover:text-white transition-all duration-200 text-sm font-medium"
              >
                Disconnect
              </button>
            </div>
          ) : (
            <button
              onClick={onConnect}
              className="px-6 py-2 bg-[#c5ff4a] hover:bg-[#b0e641] text-neutral-900 font-semibold rounded-lg transition-all duration-200"
            >
              Connect
            </button>
          )}
        </div>
      </div>
    </nav>
  )
}

