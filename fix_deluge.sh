#!/bin/bash
# Comprehensive Deluge diagnostic and fix script
# Run this on your Debian VM to diagnose and fix the torrent adding issue

set -e

echo "=== Deluge Diagnostic and Fix Script ==="
echo ""

# 1. Check if services are running
echo "[1/8] Checking service status..."
if systemctl is-active --quiet deluged; then
    echo "✓ deluged is running"
else
    echo "✗ deluged is NOT running"
fi

if systemctl is-active --quiet deluge-web; then
    echo "✓ deluge-web is running"
else
    echo "✗ deluge-web is NOT running"
fi

# 2. Check if daemon is listening
echo ""
echo "[2/8] Checking if daemon is listening on port 58846..."
if ss -tuln | grep -q ":58846"; then
    echo "✓ Daemon is listening on port 58846"
    ss -tuln | grep ":58846"
else
    echo "✗ Daemon is NOT listening on port 58846"
fi

# 3. Check web UI port
echo ""
echo "[3/8] Checking web UI port 8112..."
if ss -tuln | grep -q ":8112"; then
    echo "✓ Web UI is listening on port 8112"
else
    echo "✗ Web UI is NOT listening on port 8112"
fi

# 4. Check core.conf format
echo ""
echo "[4/8] Checking core.conf format..."
CORE_CONF="/var/lib/deluge/.config/deluge/core.conf"
if [ -f "$CORE_CONF" ]; then
    if python3 -m json.tool "$CORE_CONF" > /dev/null 2>&1; then
        echo "✓ core.conf is valid JSON"
    else
        echo "✗ core.conf is INVALID JSON (this is likely the problem!)"
        echo "  Attempting to fix..."
        
        # Stop services
        systemctl stop deluged deluge-web
        
        # Backup the broken config
        cp "$CORE_CONF" "${CORE_CONF}.backup.$(date +%s)"
        
        # Try to fix JSON - remove any plain text lines that were appended
        python3 << 'PYEOF'
import json
import sys
import re

conf_path = "/var/lib/deluge/.config/deluge/core.conf"

try:
    with open(conf_path, 'r') as f:
        content = f.read()
    
    # Remove any lines that look like plain text (not JSON)
    lines = content.split('\n')
    json_lines = []
    in_json = True
    
    for line in lines:
        # Stop at first non-JSON line (like "allow_remote: true")
        if re.match(r'^\s*[a-zA-Z_]+:\s*(true|false)', line):
            break
        json_lines.append(line)
    
    # Join and parse
    json_content = '\n'.join(json_lines)
    config = json.loads(json_content)
    
    # Add allow_remote properly as JSON
    config["allow_remote"] = True
    
    # Write back
    with open(conf_path, 'w') as f:
        json.dump(config, f, indent=4)
    
    print("Fixed core.conf - added allow_remote as proper JSON")
except Exception as e:
    print(f"Error fixing JSON: {e}")
    sys.exit(1)
PYEOF
        
        # Fix ownership
        chown deluge:deluge "$CORE_CONF"
        echo "  ✓ Fixed core.conf"
    fi
else
    echo "✗ core.conf does not exist"
fi

# 5. Check auth file
echo ""
echo "[5/8] Checking authentication file..."
AUTH_FILE="/var/lib/deluge/.config/deluge/auth"
if [ -f "$AUTH_FILE" ]; then
    echo "✓ Auth file exists"
    echo "  Contents:"
    cat "$AUTH_FILE" | head -1
else
    echo "✗ Auth file missing - creating it..."
    echo "deluge:deluge:10" | tee "$AUTH_FILE"
    chown deluge:deluge "$AUTH_FILE"
    chmod 600 "$AUTH_FILE"
    echo "  ✓ Created auth file"
fi

# 6. Check VPN interface binding
echo ""
echo "[6/8] Checking VPN interface binding..."
if [ -f "$CORE_CONF" ]; then
    if grep -q '"outgoing_interface": "proton"' "$CORE_CONF"; then
        echo "✓ Deluge is bound to 'proton' interface"
    else
        echo "⚠ Deluge may not be bound to VPN interface"
    fi
fi

# Check if proton interface exists
if ip a | grep -q "proton"; then
    echo "✓ Proton VPN interface exists"
    ip a | grep -A 2 "proton" | head -3
else
    echo "⚠ Proton VPN interface not found"
fi

# 7. Check download folder
echo ""
echo "[7/8] Checking download folder..."
DOWNLOAD_DIR="/var/lib/deluge/downloads"
if [ -d "$DOWNLOAD_DIR" ]; then
    echo "✓ Download folder exists: $DOWNLOAD_DIR"
    ls -ld "$DOWNLOAD_DIR"
else
    echo "✗ Download folder missing - creating it..."
    mkdir -p "$DOWNLOAD_DIR"
    chown deluge:deluge "$DOWNLOAD_DIR"
    echo "  ✓ Created download folder"
fi

# 8. Restart services
echo ""
echo "[8/8] Restarting services..."
systemctl restart deluged deluge-web
sleep 2

# Final status check
echo ""
echo "=== Final Status Check ==="
systemctl status deluged --no-pager -l | head -5
echo ""
systemctl status deluge-web --no-pager -l | head -5

echo ""
echo "=== Diagnostic Complete ==="
echo ""
echo "Next steps:"
echo "1. Open http://192.168.83.128:8112 in your browser"
echo "2. Log in with password: deluge"
echo "3. Open Connection Manager (plug icon bottom-left)"
echo "4. Remove any existing connections"
echo "5. Add new connection:"
echo "   - Host: localhost"
echo "   - Port: 58846"
echo "   - Username: (leave blank or 'deluge')"
echo "   - Password: deluge"
echo "6. Click Connect"
echo "7. Try adding a torrent again"
echo ""
echo "If it still doesn't work, check the logs:"
echo "  sudo journalctl -u deluged -n 50"
echo "  sudo journalctl -u deluge-web -n 50"

