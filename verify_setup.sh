#!/bin/bash
# Quick verification script

echo "=== Verifying Deluge Setup ==="
echo ""

# Check services
echo "[1] Service Status:"
if systemctl is-active --quiet deluged; then
    echo "  ✓ deluged is running"
else
    echo "  ✗ deluged is NOT running"
fi

if systemctl is-active --quiet deluge-web; then
    echo "  ✓ deluge-web is running"
else
    echo "  ✗ deluge-web is NOT running"
fi

# Check daemon port
echo ""
echo "[2] Daemon Connection:"
if ss -tuln | grep -q ":58846"; then
    echo "  ✓ Daemon is listening on port 58846"
    ss -tuln | grep ":58846"
else
    echo "  ⚠ Daemon not listening yet (may need a few more seconds)"
    echo "  Try: sudo systemctl restart deluged && sleep 3"
fi

# Check web UI port
echo ""
echo "[3] Web UI:"
if ss -tuln | grep -q ":8112"; then
    echo "  ✓ Web UI is listening on port 8112"
else
    echo "  ✗ Web UI not listening"
fi

# Verify core.conf
echo ""
echo "[4] Configuration:"
if sudo -u deluge python3 -m json.tool /var/lib/deluge/.config/deluge/core.conf > /dev/null 2>&1; then
    echo "  ✓ core.conf is valid JSON"
    
    # Check key settings
    if sudo -u deluge grep -q '"allow_remote": true' /var/lib/deluge/.config/deluge/core.conf; then
        echo "  ✓ allow_remote is set to true"
    else
        echo "  ✗ allow_remote not found or incorrect"
    fi
    
    if sudo -u deluge grep -q '"outgoing_interface": "proton"' /var/lib/deluge/.config/deluge/core.conf; then
        echo "  ✓ VPN interface binding is set (proton)"
    else
        echo "  ⚠ VPN interface binding may not be set"
    fi
else
    echo "  ✗ core.conf is INVALID JSON"
fi

# Check auth file
echo ""
echo "[5] Authentication:"
if [ -f /var/lib/deluge/.config/deluge/auth ]; then
    echo "  ✓ Auth file exists"
    echo "  Contents: $(sudo -u deluge head -1 /var/lib/deluge/.config/deluge/auth)"
else
    echo "  ✗ Auth file missing"
fi

# Check VPN interface
echo ""
echo "[6] VPN Interface:"
if ip a | grep -q "proton"; then
    echo "  ✓ Proton VPN interface exists"
    ip a | grep -A 1 "proton" | head -2
else
    echo "  ⚠ Proton VPN interface not found (VPN may be down)"
fi

echo ""
echo "=== Summary ==="
echo "If all checks pass, proceed to browser steps:"
echo "1. Open http://192.168.83.128:8112"
echo "2. Clear cache or use Incognito mode"
echo "3. Log in with password: deluge"
echo "4. Connection Manager → Remove old → Add new (localhost:58846, deluge/deluge)"
echo "5. Connect and try adding a torrent"

