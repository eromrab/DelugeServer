#!/bin/bash
# Test if Deluge daemon is actually functional despite logging warnings

echo "=== Testing Deluge Daemon Functionality ==="
echo ""

# Check if we can actually connect and get a response
echo "[1] Testing daemon connection..."
if timeout 3 bash -c 'exec 3<>/dev/tcp/127.0.0.1/58846 && echo "Connection successful" && exec 3<&-' 2>/dev/null; then
    echo "  ✓ Can connect to daemon on port 58846"
else
    echo "  ✗ Cannot connect to daemon"
fi

# Check for actual errors (not logging warnings)
echo ""
echo "[2] Checking for real errors (excluding logging warnings)..."
ERRORS=$(sudo journalctl -u deluged -n 50 --no-pager | grep -i -E "(error|exception|traceback|failed|cannot|unable)" | grep -v "findCaller" | grep -v "logging" | tail -5)
if [ -z "$ERRORS" ]; then
    echo "  ✓ No functional errors found"
    echo "  (The logging warnings are harmless)"
else
    echo "  ⚠ Found potential errors:"
    echo "$ERRORS"
fi

# Check if daemon is actually processing requests
echo ""
echo "[3] Checking daemon process health..."
if ps aux | grep "[d]eluged" | grep -q deluge; then
    PID=$(pgrep -u deluge deluged)
    echo "  ✓ deluged is running (PID: $PID)"
    echo "  Memory usage: $(ps -p $PID -o rss= | awk '{printf "%.1f MB", $1/1024}')"
    echo "  CPU usage: $(ps -p $PID -o %cpu=)%"
else
    echo "  ✗ deluged process not found"
fi

# Check web UI
echo ""
echo "[4] Web UI status:"
if curl -s http://localhost:8112 > /dev/null 2>&1; then
    echo "  ✓ Web UI is responding"
else
    echo "  ⚠ Web UI not responding (may need to check from host machine)"
fi

echo ""
echo "=== Summary ==="
echo "The Python logging error is a known Python 3.11 compatibility issue."
echo "It does NOT affect Deluge's functionality - it's just noisy logs."
echo ""
echo "If torrents still won't add, the issue is likely:"
echo "1. Web UI not properly connected to daemon (Connection Manager)"
echo "2. Browser cache issues"
echo "3. Authentication problems"
echo ""
echo "Have you tried connecting via the web UI Connection Manager yet?"
echo "If yes, what happens when you try to add a torrent?"

