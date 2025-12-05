#!/bin/bash
# Fix authentication issue - daemon not recognizing username

echo "=== Fixing Authentication Issue ==="
echo ""

# Stop services
echo "[1] Stopping services..."
sudo systemctl stop deluged deluge-web

# Check current auth file
echo "[2] Current auth file:"
if [ -f /var/lib/deluge/.config/deluge/auth ]; then
    echo "  Current contents:"
    sudo -u deluge cat /var/lib/deluge/.config/deluge/auth
else
    echo "  ✗ Auth file missing!"
fi

# Recreate auth file with proper format
echo ""
echo "[3] Recreating auth file..."
sudo -u deluge mkdir -p /var/lib/deluge/.config/deluge

# Create auth file - format: username:password:level (10 = admin)
echo "deluge:deluge:10" | sudo -u deluge tee /var/lib/deluge/.config/deluge/auth > /dev/null
sudo chown deluge:deluge /var/lib/deluge/.config/deluge/auth
sudo chmod 600 /var/lib/deluge/.config/deluge/auth

echo "  ✓ Created auth file"
echo "  Contents: $(sudo -u deluge cat /var/lib/deluge/.config/deluge/auth)"

# Also check if there's a hosts.conf that might be blocking
echo ""
echo "[4] Checking hosts.conf (IP whitelist)..."
if [ -f /var/lib/deluge/.config/deluge/hosts.conf ]; then
    echo "  hosts.conf exists:"
    sudo -u deluge cat /var/lib/deluge/.config/deluge/hosts.conf
    echo ""
    echo "  ⚠ If this file restricts IPs, it might block connections"
    echo "  Removing it to allow all connections..."
    sudo -u deluge rm -f /var/lib/deluge/.config/deluge/hosts.conf
else
    echo "  ✓ No hosts.conf (no IP restrictions)"
fi

# Ensure allow_remote is set
echo ""
echo "[5] Verifying allow_remote setting..."
sudo -u deluge python3 << 'EOF'
import json

conf_path = "/var/lib/deluge/.config/deluge/core.conf"
with open(conf_path, 'r') as f:
    config = json.load(f)

config["allow_remote"] = True

with open(conf_path, 'w') as f:
    json.dump(config, f, indent=4)

print("  ✓ allow_remote is True")
EOF

# Restart services
echo ""
echo "[6] Restarting services..."
sudo systemctl start deluged deluge-web
sleep 3

# Verify daemon is listening
echo ""
echo "[7] Verifying daemon is listening..."
if sudo ss -tuln | grep -q ":58846"; then
    echo "  ✓ Daemon is listening on port 58846"
    sudo ss -tuln | grep ":58846"
else
    echo "  ✗ Daemon is NOT listening"
    echo "  Check logs: sudo journalctl -u deluged -n 20"
fi

# Test connection
echo ""
echo "[8] Testing connection..."
if command -v deluge-console > /dev/null 2>&1; then
    echo "  Testing with deluge-console..."
    timeout 5 sudo -u deluge deluge-console "connect 127.0.0.1:58846 deluge deluge; info" 2>&1 | head -10
    if [ $? -eq 0 ]; then
        echo "  ✓ Connection successful!"
    else
        echo "  ✗ Connection failed"
    fi
fi

echo ""
echo "=== Next Steps ==="
echo "1. Try connecting via web UI:"
echo "   - Connection Manager → Remove old → Add new"
echo "   - Host: 127.0.0.1"
echo "   - Port: 58846"
echo "   - Username: deluge"
echo "   - Password: deluge"
echo ""
echo "2. Or test with deluge-console:"
echo "   sudo -u deluge deluge-console 'connect 127.0.0.1:58846 deluge deluge; add magnet:?xt=urn:btih:9c4e2d5e4f9d8e7b8d0c8e5f6d7e8f9a0b1c2d3e&dn=test&tr=udp://tracker.opentrackr.org:1337/announce'"

