#!/bin/bash
# Check what's happening when Deluge creates the config

echo "=== Checking Config Creation ==="
echo ""

# Stop and remove
sudo systemctl stop deluged
sudo rm -f /var/lib/deluged/config/core.conf

# Start and watch the file
echo "[1] Starting daemon and watching config file..."
sudo systemctl start deluged

# Monitor the file as it's created
for i in {1..15}; do
    if [ -f /var/lib/deluged/config/core.conf ]; then
        echo ""
        echo "  Config file appeared at iteration $i"
        echo "  File size: $(stat -c%s /var/lib/deluged/config/core.conf) bytes"
        echo "  First 100 chars:"
        sudo -u debian-deluged head -c 100 /var/lib/deluged/config/core.conf
        echo ""
        echo "  Checking if valid JSON..."
        if sudo -u debian-deluged python3 -m json.tool /var/lib/deluged/config/core.conf > /dev/null 2>&1; then
            echo "  ✓ Valid JSON at this point"
        else
            echo "  ✗ Invalid JSON already!"
            echo "  Full content:"
            sudo -u debian-deluged cat /var/lib/deluged/config/core.conf
            break
        fi
    fi
    sleep 1
done

# Check if it gets corrupted after creation
echo ""
echo "[2] Waiting 5 more seconds to see if it gets corrupted..."
sleep 5

if sudo -u debian-deluged python3 -m json.tool /var/lib/deluged/config/core.conf > /dev/null 2>&1; then
    echo "  ✓ Config is still valid"
else
    echo "  ✗ Config got corrupted!"
    echo "  Current content (first 200 chars):"
    sudo -u debian-deluged head -c 200 /var/lib/deluged/config/core.conf
    echo ""
fi

# Check for multiple processes writing
echo ""
echo "[3] Checking for processes that might be writing to config:"
sudo lsof /var/lib/deluged/config/core.conf 2>/dev/null || echo "  (lsof not available or no processes found)"

