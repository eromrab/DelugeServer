#!/bin/bash
# Comprehensive web UI connection diagnostic

echo "=== Web UI Connection Diagnostic ==="
echo ""

# Check auth file format
echo "[1] Authentication file:"
if [ -f /var/lib/deluge/.config/deluge/auth ]; then
    echo "  ✓ Auth file exists"
    echo "  Contents: $(sudo -u deluge cat /var/lib/deluge/.config/deluge/auth)"
    
    # Check format
    AUTH_LINE=$(sudo -u deluge head -1 /var/lib/deluge/.config/deluge/auth)
    if echo "$AUTH_LINE" | grep -qE "^[^:]+:[^:]+:[0-9]+$"; then
        echo "  ✓ Format looks correct (username:password:level)"
    else
        echo "  ✗ Format may be incorrect"
    fi
else
    echo "  ✗ Auth file missing!"
fi

# Check if daemon is listening on the right interface
echo ""
echo "[2] Daemon listening status:"
DAEMON_LISTEN=$(sudo ss -tuln | grep 58846)
echo "  $DAEMON_LISTEN"

if echo "$DAEMON_LISTEN" | grep -q "127.0.0.1"; then
    echo "  ✓ Daemon is listening on localhost (correct)"
else
    echo "  ⚠ Daemon may not be listening on localhost"
fi

# Check web UI config
echo ""
echo "[3] Web UI configuration:"
if [ -f /var/lib/deluge/.config/deluge/web.conf ]; then
    echo "  ✓ web.conf exists"
    sudo -u deluge cat /var/lib/deluge/.config/deluge/web.conf | head -10
else
    echo "  ⚠ web.conf does not exist (will be created on first connection)"
fi

# Check core.conf allow_remote
echo ""
echo "[4] Core configuration:"
if sudo -u deluge grep -q '"allow_remote": true' /var/lib/deluge/.config/deluge/core.conf; then
    echo "  ✓ allow_remote is true"
else
    echo "  ✗ allow_remote is NOT true (this is the problem!)"
fi

# Test RPC connection
echo ""
echo "[5] Testing RPC connection..."
if command -v deluge-console > /dev/null 2>&1; then
    echo "  Testing with deluge-console..."
    timeout 5 sudo -u deluge deluge-console "connect localhost:58846 deluge deluge; info" 2>&1 | head -5
    if [ $? -eq 0 ]; then
        echo "  ✓ RPC connection works"
    else
        echo "  ✗ RPC connection failed"
    fi
else
    echo "  ⚠ deluge-console not installed (install with: sudo apt install deluge-console)"
fi

echo ""
echo "=== Most Likely Issue ==="
echo "The web UI may be connecting but not authenticated properly."
echo ""
echo "Try this fix:"
echo "1. In browser: Connection Manager → Remove ALL connections"
echo "2. Add new connection with EXACTLY these values:"
echo "   - Host: 127.0.0.1 (not localhost)"
echo "   - Port: 58846"
echo "   - Username: deluge"
echo "   - Password: deluge"
echo "3. Click Add → Connect"
echo "4. Verify it shows 'Online' and green"
echo "5. Try adding torrent again"
echo ""
echo "If that doesn't work, check browser console (F12) for JavaScript errors"

