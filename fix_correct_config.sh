#!/bin/bash
# Fix: Deluge is using /var/lib/deluged/config, not /var/lib/deluge/.config/deluge

echo "=== Fixing Deluge Configuration Location ==="
echo ""

# Stop services
echo "[1] Stopping services..."
sudo systemctl stop deluged deluge-web

# Check the correct config directory
echo ""
echo "[2] Checking correct config directory..."
CORRECT_CONFIG="/var/lib/deluged/config"
CORRECT_USER="debian-deluged"

if [ -d "$CORRECT_CONFIG" ]; then
    echo "  ✓ Found config directory: $CORRECT_CONFIG"
    ls -la "$CORRECT_CONFIG" | head -10
else
    echo "  ✗ Config directory doesn't exist, creating it..."
    sudo mkdir -p "$CORRECT_CONFIG"
    sudo chown $CORRECT_USER:$CORRECT_USER "$CORRECT_CONFIG"
fi

# Create auth file in the CORRECT location
echo ""
echo "[3] Creating auth file in correct location..."
echo "deluge:deluge:10" | sudo tee "$CORRECT_CONFIG/auth" > /dev/null
sudo chown $CORRECT_USER:$CORRECT_USER "$CORRECT_CONFIG/auth"
sudo chmod 600 "$CORRECT_CONFIG/auth"

echo "  ✓ Created: $CORRECT_CONFIG/auth"
echo "  Contents: $(cat "$CORRECT_CONFIG/auth")"

# Check if core.conf exists in correct location
echo ""
echo "[4] Checking core.conf..."
if [ -f "$CORRECT_CONFIG/core.conf" ]; then
    echo "  ✓ core.conf exists in correct location"
    
    # Ensure allow_remote is true
    sudo -u $CORRECT_USER python3 << 'EOF'
import json
conf_path = "/var/lib/deluged/config/core.conf"
try:
    with open(conf_path, 'r') as f:
        config = json.load(f)
    config["allow_remote"] = True
    with open(conf_path, 'w') as f:
        json.dump(config, f, indent=4)
    print("  ✓ Updated allow_remote to True")
except Exception as e:
    print(f"  ✗ Error: {e}")
EOF
else
    echo "  ⚠ core.conf doesn't exist yet (will be created on first start)"
fi

# Fix permissions on entire config directory
echo ""
echo "[5] Fixing permissions..."
sudo chown -R $CORRECT_USER:$CORRECT_USER "$CORRECT_CONFIG"
sudo chmod 700 "$CORRECT_CONFIG"

# Restart services
echo ""
echo "[6] Starting services..."
sudo systemctl start deluged
sleep 5

# Verify
echo ""
echo "[7] Verification..."
if systemctl is-active --quiet deluged; then
    echo "  ✓ deluged is running"
else
    echo "  ✗ deluged failed to start"
    echo "  Check logs: sudo journalctl -u deluged -n 20"
fi

if sudo ss -tuln | grep -q ":58846"; then
    echo "  ✓ Daemon is listening on port 58846"
else
    echo "  ⚠ Daemon not listening yet"
fi

# Test connection
echo ""
echo "[8] Testing connection..."
if command -v deluge-console > /dev/null 2>&1; then
    echo "  Attempting to connect..."
    timeout 5 sudo -u deluge deluge-console "connect 127.0.0.1:58846 deluge deluge; info" 2>&1 | head -10
fi

echo ""
echo "=== Summary ==="
echo "Deluge was looking for config in: $CORRECT_CONFIG"
echo "Auth file is now at: $CORRECT_CONFIG/auth"
echo ""
echo "If connection still fails, check:"
echo "  sudo journalctl -u deluged -n 30 | grep -i auth"

