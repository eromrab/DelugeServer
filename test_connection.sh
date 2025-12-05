#!/bin/bash
# Test if authentication is now working

echo "=== Testing Deluge Connection ==="
echo ""

# Check if daemon is running
echo "[1] Service status:"
if systemctl is-active --quiet deluged; then
    echo "  ✓ deluged is running"
else
    echo "  ✗ deluged is NOT running"
    echo "  Starting it..."
    sudo systemctl start deluged
    sleep 5
fi

# Check if listening
echo ""
echo "[2] Listening status:"
if sudo ss -tuln | grep -q ":58846"; then
    echo "  ✓ Daemon is listening on port 58846"
    sudo ss -tuln | grep ":58846"
else
    echo "  ✗ Daemon is NOT listening"
    echo "  Check logs: sudo journalctl -u deluged -n 20"
fi

# Verify auth file exists
echo ""
echo "[3] Auth file check:"
if [ -f /var/lib/deluged/config/auth ]; then
    echo "  ✓ Auth file exists"
    echo "  Contents: $(cat /var/lib/deluged/config/auth)"
    echo "  Permissions: $(ls -l /var/lib/deluged/config/auth | awk '{print $1, $3, $4}')"
else
    echo "  ✗ Auth file missing!"
fi

# Test connection
echo ""
echo "[4] Testing connection (ignoring gettext warnings)..."
if command -v deluge-console > /dev/null 2>&1; then
    CONNECT_OUTPUT=$(timeout 5 sudo -u deluge deluge-console "connect 127.0.0.1:58846 deluge deluge; info" 2>&1)
    
    # Filter out the harmless gettext warnings
    CLEAN_OUTPUT=$(echo "$CONNECT_OUTPUT" | grep -v "gettext\|bind_textdomain\|AttributeError\|Traceback\|File \"/usr/lib" | head -10)
    
    if echo "$CONNECT_OUTPUT" | grep -q "Connected to\|Connection successful\|Daemon info"; then
        echo "  ✓ Connection successful!"
        echo "$CLEAN_OUTPUT"
    elif echo "$CONNECT_OUTPUT" | grep -q "Username does not exist"; then
        echo "  ✗ Still getting 'Username does not exist'"
        echo "  This means auth file still not being read"
        echo ""
        echo "  Check:"
        echo "    sudo ls -la /var/lib/deluged/config/"
        echo "    sudo journalctl -u deluged -n 30 | grep -i auth"
    else
        echo "  ⚠ Connection attempt made, checking output:"
        echo "$CLEAN_OUTPUT"
    fi
else
    echo "  ⚠ deluge-console not available"
fi

echo ""
echo "=== If connection works, try adding a torrent ==="
echo "sudo -u deluge deluge-console 'connect 127.0.0.1:58846 deluge deluge; add magnet:?xt=urn:btih:9c4e2d5e4f9d8e7b8d0c8e5f6d7e8f9a0b1c2d3e&dn=test&tr=udp://tracker.opentrackr.org:1337/announce; status'"

