#!/bin/bash
# Test adding a torrent directly to the daemon (bypassing web UI)

echo "=== Testing Direct Torrent Add to Daemon ==="
echo ""

# First, check if deluge-console is available
if command -v deluge-console > /dev/null 2>&1; then
    echo "[1] deluge-console is available"
    
    # Try to connect and add a test torrent
    echo "[2] Attempting to connect to daemon..."
    sudo -u deluge deluge-console << 'CONSOLE'
connect localhost:58846 deluge deluge
info
add magnet:?xt=urn:btih:9c4e2d5e4f9d8e7b8d0c8e5f6d7e8f9a0b1c2d3e&dn=test&tr=udp://tracker.opentrackr.org:1337/announce
status
quit
CONSOLE
    
    echo ""
    echo "[3] Checking if torrent was added..."
    sleep 2
    sudo -u deluge ls -la /var/lib/deluge/.config/deluge/state/ | grep -E "\.torrent$" | tail -3
    
else
    echo "[1] deluge-console not installed"
    echo "    Installing it..."
    sudo apt install deluge-console -y
    
    echo "[2] Now trying to connect..."
    sudo -u deluge deluge-console << 'CONSOLE'
connect localhost:58846 deluge deluge
info
add magnet:?xt=urn:btih:9c4e2d5e4f9d8e7b8d0c8e5f6d7e8f9a0b1c2d3e&dn=test&tr=udp://tracker.opentrackr.org:1337/announce
status
quit
CONSOLE
fi

echo ""
echo "=== Alternative: Check Web UI Connection ==="
echo "The issue might be that the web UI isn't actually connected to the daemon."
echo ""
echo "In your browser at http://192.168.83.128:8112:"
echo "1. Open browser Developer Tools (F12)"
echo "2. Go to Console tab"
echo "3. Try adding a torrent"
echo "4. Look for any JavaScript errors in the console"
echo ""
echo "Also check Network tab to see if the add request is being sent"

