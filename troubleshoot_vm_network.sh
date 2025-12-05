#!/bin/bash
# Troubleshoot VM Internet Connectivity Issues

echo "=== VM Network Connectivity Diagnostics ==="
echo ""

# 1. Check network interfaces
echo "[1] Network Interfaces:"
ip a
echo ""

# 2. Check default gateway
echo "[2] Default Gateway:"
ip route | grep default || echo "  ✗ No default gateway configured!"
echo ""

# 3. Check DNS configuration
echo "[3] DNS Configuration:"
cat /etc/resolv.conf 2>/dev/null || echo "  ✗ /etc/resolv.conf not found or empty"
echo ""

# 4. Test basic connectivity
echo "[4] Testing Connectivity:"
echo "  Testing gateway..."
GATEWAY=$(ip route | grep default | awk '{print $3}' | head -1)
if [ -n "$GATEWAY" ]; then
    if ping -c 2 -W 2 $GATEWAY > /dev/null 2>&1; then
        echo "  ✓ Gateway ($GATEWAY) is reachable"
    else
        echo "  ✗ Gateway ($GATEWAY) is NOT reachable"
    fi
else
    echo "  ✗ No gateway found to test"
fi

echo "  Testing DNS (8.8.8.8)..."
if ping -c 2 -W 2 8.8.8.8 > /dev/null 2>&1; then
    echo "  ✓ Google DNS (8.8.8.8) is reachable"
else
    echo "  ✗ Google DNS (8.8.8.8) is NOT reachable"
fi

echo "  Testing DNS resolution..."
if nslookup google.com > /dev/null 2>&1; then
    echo "  ✓ DNS resolution works"
else
    echo "  ✗ DNS resolution FAILED"
fi

echo "  Testing HTTP connectivity..."
if curl -s --max-time 5 http://www.google.com > /dev/null 2>&1; then
    echo "  ✓ HTTP connectivity works"
else
    echo "  ✗ HTTP connectivity FAILED"
fi
echo ""

# 5. Check VMware network adapter
echo "[5] VMware Network Adapter:"
if ip a | grep -q "ens33\|eth0\|enp0s3"; then
    echo "  ✓ VMware network adapter detected"
    INTERFACE=$(ip a | grep -oP "^\d+: \K(ens33|eth0|enp0s3)" | head -1)
    if [ -n "$INTERFACE" ]; then
        echo "  Interface: $INTERFACE"
        if ip a show $INTERFACE | grep -q "inet "; then
            IP=$(ip a show $INTERFACE | grep "inet " | awk '{print $2}' | cut -d/ -f1)
            echo "  IP Address: $IP"
        else
            echo "  ✗ No IP address assigned to $INTERFACE"
        fi
    fi
else
    echo "  ⚠ VMware network adapter not detected"
fi
echo ""

# 6. Check if VPN is interfering
echo "[6] VPN Status:"
if ip a | grep -q "proton\|tun0\|wg0"; then
    echo "  ⚠ VPN interface detected"
    if systemctl is-active --quiet wg-quick@proton 2>/dev/null; then
        echo "  Proton VPN is active"
    fi
    echo "  Note: If VPN is misconfigured, it might block internet"
else
    echo "  No VPN interface detected"
fi
echo ""

# 7. Check firewall
echo "[7] Firewall Status:"
if command -v ufw > /dev/null 2>&1; then
    UFW_STATUS=$(ufw status 2>/dev/null | head -1)
    echo "  $UFW_STATUS"
fi
if command -v iptables > /dev/null 2>&1; then
    IPTABLES_RULES=$(iptables -L -n 2>/dev/null | wc -l)
    echo "  iptables rules: $IPTABLES_RULES"
fi
echo ""

# 8. Check systemd network services
echo "[8] Network Services:"
if systemctl is-active --quiet NetworkManager 2>/dev/null; then
    echo "  ✓ NetworkManager is active"
elif systemctl is-active --quiet networking 2>/dev/null; then
    echo "  ✓ networking service is active"
else
    echo "  ⚠ Network service status unclear"
fi
echo ""

# 9. Recommendations
echo "=== Recommendations ==="
echo ""

# Check if there's no default gateway
if ! ip route | grep -q default; then
    echo "❌ ISSUE: No default gateway configured"
    echo "   Fix: Check VMware network adapter settings (should be NAT or Bridged)"
    echo "   Or manually add gateway: sudo ip route add default via <gateway-ip>"
    echo ""
fi

# Check if interface has no IP
INTERFACE=$(ip a | grep -oP "^\d+: \K(ens33|eth0|enp0s3)" | head -1)
if [ -n "$INTERFACE" ]; then
    if ! ip a show $INTERFACE | grep -q "inet "; then
        echo "❌ ISSUE: Network interface $INTERFACE has no IP address"
        echo "   Fix: Try: sudo dhclient $INTERFACE"
        echo "   Or check VMware network adapter settings"
        echo ""
    fi
fi

# Check DNS
if ! nslookup google.com > /dev/null 2>&1; then
    echo "❌ ISSUE: DNS resolution not working"
    echo "   Fix: Add DNS servers to /etc/resolv.conf:"
    echo "        echo 'nameserver 8.8.8.8' | sudo tee -a /etc/resolv.conf"
    echo "        echo 'nameserver 8.8.4.4' | sudo tee -a /etc/resolv.conf"
    echo ""
fi

echo "=== Quick Fixes to Try ==="
echo ""
echo "1. Restart network service:"
echo "   sudo systemctl restart networking"
echo "   OR"
echo "   sudo systemctl restart NetworkManager"
echo ""
echo "2. Release and renew DHCP lease:"
echo "   sudo dhclient -r"
echo "   sudo dhclient"
echo ""
echo "3. Check VMware Settings:"
echo "   - VM → Settings → Network Adapter"
echo "   - Should be set to 'NAT' (easiest) or 'Bridged'"
echo "   - Make sure adapter is connected"
echo ""
echo "4. If VPN is interfering, disconnect it temporarily:"
echo "   sudo wg-quick down proton"
echo "   Then test internet again"
echo ""
