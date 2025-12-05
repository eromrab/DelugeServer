#!/bin/bash
# Fix VM Network Connectivity Issues

echo "=== Fixing VM Network Connectivity ==="
echo ""

# 1. Check VMware network adapter status
echo "[1] Checking VMware network adapter (ens33)..."
if ip link show ens33 | grep -q "state DOWN"; then
    echo "  ⚠ ens33 is DOWN - bringing it up..."
    sudo ip link set ens33 up
    sleep 2
    if ip link show ens33 | grep -q "state UP"; then
        echo "  ✓ ens33 is now UP"
    else
        echo "  ✗ Failed to bring ens33 up"
        echo "  → Check VMware Settings: VM → Settings → Network Adapter"
        echo "  → Make sure adapter is set to 'NAT' or 'Bridged' and is connected"
        exit 1
    fi
else
    echo "  ✓ ens33 is already UP"
fi
echo ""

# 2. Get IP address via DHCP
echo "[2] Requesting IP address via DHCP..."
if ip a show ens33 | grep -q "inet "; then
    echo "  ✓ ens33 already has an IP address"
    ip a show ens33 | grep "inet "
else
    echo "  Requesting DHCP lease..."
    sudo dhclient -r ens33 2>/dev/null  # Release any old lease
    sleep 1
    if sudo dhclient -v ens33 2>&1 | grep -q "bound"; then
        echo "  ✓ IP address obtained via DHCP"
        ip a show ens33 | grep "inet "
    else
        echo "  ✗ Failed to get IP address"
        echo "  → Check VMware network adapter settings"
        echo "  → Try: sudo systemctl restart NetworkManager"
        exit 1
    fi
fi
echo ""

# 3. Check default gateway
echo "[3] Checking default gateway..."
if ip route | grep -q default; then
    echo "  ✓ Default gateway configured:"
    ip route | grep default
else
    echo "  ⚠ No default gateway - this should be set automatically by DHCP"
    echo "  → If this persists, check VMware network adapter settings"
fi
echo ""

# 4. Test connectivity
echo "[4] Testing connectivity..."
if ping -c 2 -W 2 8.8.8.8 > /dev/null 2>&1; then
    echo "  ✓ Internet connectivity works!"
else
    echo "  ✗ Still no internet connectivity"
    echo "  → Check VMware Settings: VM → Settings → Network Adapter"
    echo "  → Make sure it's set to 'NAT' (recommended) or 'Bridged'"
    echo "  → Ensure 'Connected' checkbox is checked"
fi
echo ""

# 5. Test DNS
echo "[5] Testing DNS resolution..."
if nslookup google.com > /dev/null 2>&1; then
    echo "  ✓ DNS resolution works"
else
    echo "  ⚠ DNS resolution failed - adding Google DNS as fallback..."
    echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf
    echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf
    if nslookup google.com > /dev/null 2>&1; then
        echo "  ✓ DNS resolution now works"
    else
        echo "  ✗ DNS still not working"
    fi
fi
echo ""

# 6. Check VPN status
echo "[6] VPN Status:"
if ip a | grep -q "proton"; then
    echo "  ✓ Proton VPN interface detected"
    if ip route | grep -q default; then
        echo "  → VPN should now work properly with internet connectivity restored"
    else
        echo "  ⚠ VPN is active but no default gateway - VPN may not work correctly"
    fi
else
    echo "  No VPN interface detected"
fi
echo ""

echo "=== Summary ==="
echo "If internet is still not working:"
echo "1. Check VMware Settings:"
echo "   - VM → Settings → Network Adapter"
echo "   - Set to 'NAT' (easiest) or 'Bridged'"
echo "   - Make sure 'Connected' is checked"
echo ""
echo "2. Restart NetworkManager:"
echo "   sudo systemctl restart NetworkManager"
echo ""
echo "3. If ens33 still won't come up, try:"
echo "   sudo ip link set ens33 down"
echo "   sudo ip link set ens33 up"
echo "   sudo dhclient ens33"
echo ""
