#!/bin/bash
# Comprehensive auth fix - daemon not reading auth file

echo "=== Comprehensive Authentication Fix ==="
echo ""

# Stop services
echo "[1] Stopping services..."
sudo systemctl stop deluged deluge-web
sleep 2

# Check if daemon process is still running
if pgrep -u deluge deluged > /dev/null; then
    echo "  Killing any remaining deluged processes..."
    sudo pkill -u deluge deluged
    sleep 1
fi

# Check all possible auth file locations
echo ""
echo "[2] Checking auth file locations..."
AUTH_PATHS=(
    "/var/lib/deluge/.config/deluge/auth"
    "/home/deluge/.config/deluge/auth"
    "$(sudo -u deluge printenv HOME)/.config/deluge/auth"
)

for path in "${AUTH_PATHS[@]}"; do
    if [ -f "$path" ]; then
        echo "  Found: $path"
        echo "    Contents: $(sudo -u deluge cat "$path" 2>/dev/null || echo 'cannot read')"
        echo "    Permissions: $(ls -l "$path" | awk '{print $1, $3, $4}')"
    fi
done

# Remove ALL existing auth files and recreate
echo ""
echo "[3] Removing all existing auth files..."
for path in "${AUTH_PATHS[@]}"; do
    if [ -f "$path" ]; then
        sudo -u deluge rm -f "$path"
        echo "  Removed: $path"
    fi
done

# Create auth file in the correct location
echo ""
echo "[4] Creating new auth file..."
AUTH_DIR="/var/lib/deluge/.config/deluge"
sudo -u deluge mkdir -p "$AUTH_DIR"

# Create auth file with proper format
echo "deluge:deluge:10" | sudo -u deluge tee "$AUTH_DIR/auth" > /dev/null
sudo chown deluge:deluge "$AUTH_DIR/auth"
sudo chmod 600 "$AUTH_DIR/auth"

echo "  ✓ Created: $AUTH_DIR/auth"
echo "  Contents: $(sudo -u deluge cat "$AUTH_DIR/auth")"
echo "  Permissions: $(ls -l "$AUTH_DIR/auth" | awk '{print $1, $3, $4}')"

# Verify daemon can read it
echo ""
echo "[5] Verifying daemon user can read auth file..."
if sudo -u deluge test -r "$AUTH_DIR/auth"; then
    echo "  ✓ Daemon user can read auth file"
else
    echo "  ✗ Daemon user CANNOT read auth file (permission issue!)"
fi

# Check if there's a session state that needs clearing
echo ""
echo "[6] Clearing any session state..."
sudo -u deluge rm -f "$AUTH_DIR/session.state"
echo "  ✓ Cleared session state"

# Ensure core.conf has allow_remote
echo ""
echo "[7] Verifying core.conf..."
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
echo "[8] Starting services..."
sudo systemctl start deluged
sleep 5  # Give it more time to start

# Check if it's running
if systemctl is-active --quiet deluged; then
    echo "  ✓ deluged is running"
else
    echo "  ✗ deluged failed to start"
    echo "  Check logs: sudo journalctl -u deluged -n 20"
fi

# Check if it's listening
echo ""
echo "[9] Checking if daemon is listening..."
sleep 2
if sudo ss -tuln | grep -q ":58846"; then
    echo "  ✓ Daemon is listening on port 58846"
    sudo ss -tuln | grep ":58846"
else
    echo "  ✗ Daemon is NOT listening"
fi

# Try to connect
echo ""
echo "[10] Testing connection..."
sleep 2
if command -v deluge-console > /dev/null 2>&1; then
    echo "  Attempting connection..."
    # Try multiple times with delays
    for i in 1 2 3; do
        echo "  Attempt $i..."
        CONNECT_OUTPUT=$(timeout 5 sudo -u deluge deluge-console "connect 127.0.0.1:58846 deluge deluge; info" 2>&1)
        if echo "$CONNECT_OUTPUT" | grep -q "Connected to"; then
            echo "  ✓ Connection successful!"
            echo "$CONNECT_OUTPUT" | head -5
            break
        else
            echo "  ⚠ Connection failed, waiting..."
            sleep 3
        fi
    done
fi

echo ""
echo "=== If still failing, check: ==="
echo "1. Daemon logs: sudo journalctl -u deluged -n 30 | grep -i auth"
echo "2. Auth file: sudo -u deluge cat /var/lib/deluge/.config/deluge/auth"
echo "3. Daemon process: ps aux | grep deluged"

