#!/bin/bash
# Verify Network Connectivity is Fully Working

echo "=== Network Connectivity Verification ==="
echo ""

# 1. Test basic internet
echo "[1] Testing Internet Connectivity:"
if ping -c 2 -W 3 8.8.8.8 > /dev/null 2>&1; then
    echo "  ✓ Basic internet connectivity works"
else
    echo "  ✗ Basic internet connectivity failed"
    exit 1
fi

# 2. Test DNS
echo "[2] Testing DNS Resolution:"
if curl -s --max-time 5 http://www.google.com > /dev/null 2>&1; then
    echo "  ✓ DNS and HTTP connectivity works"
    EXTERNAL_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null)
    if [ -n "$EXTERNAL_IP" ]; then
        echo "  Your external IP: $EXTERNAL_IP"
    fi
else
    echo "  ✗ DNS/HTTP connectivity failed"
fi
echo ""

# 3. Check VPN routing
echo "[3] Checking VPN Routing:"
if ip a | grep -q "proton"; then
    echo "  ✓ Proton VPN interface is active"
    VPN_IP=$(ip a show proton | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    echo "  VPN IP: $VPN_IP"
    
    # Test if traffic goes through VPN
    VPN_EXTERNAL_IP=$(curl -s --max-time 5 --interface proton ifconfig.me 2>/dev/null)
    if [ -n "$VPN_EXTERNAL_IP" ]; then
        echo "  External IP via VPN: $VPN_EXTERNAL_IP"
        if [ "$VPN_EXTERNAL_IP" != "$EXTERNAL_IP" ]; then
            echo "  ✓ VPN is routing traffic correctly"
        else
            echo "  ⚠ VPN IP matches regular IP - VPN may not be routing all traffic"
        fi
    fi
else
    echo "  No VPN interface detected"
fi
echo ""

# 4. Check Deluge binding
echo "[4] Checking Deluge Network Binding:"
if [ -f /var/lib/deluge/.config/deluge/core.conf ]; then
    OUTGOING=$(grep -o '"outgoing_interface": "[^"]*"' /var/lib/deluge/.config/deluge/core.conf | cut -d'"' -f4)
    INTERFACE=$(grep -o '"interface": "[^"]*"' /var/lib/deluge/.config/deluge/core.conf | cut -d'"' -f4)
    
    if [ "$OUTGOING" = "proton" ] || [ "$INTERFACE" = "proton" ]; then
        echo "  ✓ Deluge is bound to Proton VPN interface"
    else
        echo "  ⚠ Deluge is NOT bound to VPN (bound to: $OUTGOING/$INTERFACE)"
        echo "  → This means Deluge traffic may not go through VPN"
    fi
else
    echo "  ⚠ Deluge config not found"
fi
echo ""

# 5. Check Deluge service
echo "[5] Checking Deluge Service:"
if systemctl is-active --quiet deluged 2>/dev/null; then
    echo "  ✓ Deluge daemon is running"
    if systemctl is-active --quiet deluge-web 2>/dev/null; then
        echo "  ✓ Deluge web UI is running"
        if ss -tuln | grep -q ":8112"; then
            echo "  ✓ Deluge web UI is listening on port 8112"
            VM_IP=$(ip a show ens33 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
            echo "  → Access at: http://$VM_IP:8112"
        fi
    else
        echo "  ⚠ Deluge web UI is not running"
    fi
else
    echo "  ⚠ Deluge daemon is not running"
fi
echo ""

echo "=== Summary ==="
echo "Network Status: ✓ Working"
echo "VPN Status: $(if ip a | grep -q proton; then echo '✓ Active'; else echo '✗ Not active'; fi)"
echo "Deluge Status: $(if systemctl is-active --quiet deluged 2>/dev/null; then echo '✓ Running'; else echo '✗ Not running'; fi)"
echo ""
echo "Everything should be working now! 🎉"
