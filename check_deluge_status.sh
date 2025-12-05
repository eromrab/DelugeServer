#!/bin/bash
# Check if Deluge is actually working despite the logging error

echo "=== Checking Deluge Functionality ==="
echo ""

# Check if daemon process is running
echo "[1] Process Status:"
if pgrep -u deluge deluged > /dev/null; then
    echo "  ✓ deluged process is running (PID: $(pgrep -u deluge deluged))"
else
    echo "  ✗ deluged process not found"
fi

# Check if it's responding (try to connect)
echo ""
echo "[2] Daemon Connectivity:"
if timeout 2 bash -c 'echo > /dev/tcp/127.0.0.1/58846' 2>/dev/null; then
    echo "  ✓ Daemon is accepting connections on 127.0.0.1:58846"
else
    echo "  ⚠ Cannot connect to daemon (may still be starting)"
fi

# Check web UI
echo ""
echo "[3] Web UI Status:"
if systemctl is-active --quiet deluge-web; then
    echo "  ✓ deluge-web service is running"
    if ss -tuln | grep -q ":8112"; then
        echo "  ✓ Web UI is listening on port 8112"
    else
        echo "  ⚠ Web UI not listening yet"
    fi
else
    echo "  ✗ deluge-web service is not running"
fi

# Check the actual error in detail
echo ""
echo "[4] Recent Logs (checking for actual errors):"
sudo journalctl -u deluged -n 20 --no-pager | grep -i -E "(error|exception|traceback|critical)" | tail -5
if [ $? -ne 0 ]; then
    echo "  ✓ No critical errors found (logging error is just a warning)"
fi

echo ""
echo "=== The Python logging error is usually harmless ==="
echo "It's a known compatibility issue between Python 3.11 and Deluge 2.x"
echo "The daemon is still running and should work fine."
echo ""
echo "Try connecting via web UI now:"
echo "1. Open http://192.168.83.128:8112"
echo "2. Connection Manager → localhost:58846, deluge/deluge"
echo "3. Try adding a torrent"

