

echo "========================================"
echo "Chrono Protocol - Vault Data Update"
echo "========================================"
echo ""

# Change to script directory
cd "$(dirname "$0")"

echo "[1/3] Fetching vault data from Flow testnet..."
node update-vault-data.js

if [ $? -ne 0 ]; then
    echo ""
    echo "ERROR: Failed to fetch vault data"
    echo "Please check:"
    echo "  - Flow CLI is installed and configured"
    echo "  - Network connection is stable"
    echo "  - Flow testnet is accessible"
    exit 1
fi

echo ""
echo "[2/3] Copying vault.json to web app..."
cp vault.json chrono-web/public/vault.json

if [ $? -ne 0 ]; then
    echo ""
    echo "ERROR: Failed to copy vault.json"
    echo "Make sure chrono-web/public/ directory exists"
    exit 1
fi

echo ""
echo "[3/3] Update complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo "  - Vault data has been updated"
echo "  - Web app will automatically use the new data"
echo "  - This script will run again in 3 hours"
echo ""
echo "========================================"

exit 0






