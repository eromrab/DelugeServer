#!/bin/bash
# Get the full error details from Deluge logs

echo "=== Getting Full Error Details ==="
echo ""

# Get the full exception traceback
echo "[1] Full exception details:"
sudo journalctl -u deluged --since "10 minutes ago" --no-pager | grep -A 20 "Unhandled error" | head -30

echo ""
echo "[2] Checking for specific add torrent errors:"
sudo journalctl -u deluged --since "10 minutes ago" --no-pager | grep -i -E "(add|torrent|magnet)" | tail -10

echo ""
echo "[3] Most recent errors:"
sudo journalctl -u deluged -n 50 --no-pager | grep -B 5 -A 10 "Unhandled error" | tail -20

