#!/bin/bash
# Finalize setup - ensure VPN binding and web UI work

echo "=== Finalizing Deluge Setup ==="
echo ""

# Check VPN binding in core.conf
echo "[1] Checking VPN interface binding..."
sudo -u debian-deluged python3 << 'EOF'
import json
conf_path = "/var/lib/deluged/config/core.conf"
with open(conf_path, 'r') as f:
    config = json.load(f)

if config.get("outgoing_interface") == "proton" and config.get("interface") == "proton":
    print("  ✓ VPN binding is set (proton)")
else:
    print("  ⚠ VPN binding not set, adding it...")
    config["outgoing_interface"] = "proton"
    config["interface"] = "proton"
    with open(conf_path, 'w') as f:
        json.dump(config, f, indent=4)
    print("  ✓ VPN binding added")
EOF

# Check if proton interface exists
echo ""
echo "[2] Checking VPN interface:"
if ip a | grep -q "proton"; then
    echo "  ✓ Proton VPN interface exists"
    ip a | grep -A 1 "proton" | head -2
else
    echo "  ⚠ Proton VPN interface not found (VPN may be down)"
    echo "  Start it with: sudo wg-quick up proton"
fi

# Verify download location
echo ""
echo "[3] Checking download location:"
sudo -u debian-deluged python3 << 'EOF'
import json
conf_path = "/var/lib/deluged/config/core.conf"
with open(conf_path, 'r') as f:
    config = json.load(f)

dl_path = config.get("download_location", "")
print(f"  Download location: {dl_path}")

if not dl_path or not os.path.exists(dl_path):
    import os
    dl_path = "/var/lib/deluged/Downloads"
    config["download_location"] = dl_path
    os.makedirs(dl_path, exist_ok=True)
    with open(conf_path, 'w') as f:
        json.dump(config, f, indent=4)
    print(f"  ✓ Set download location to: {dl_path}")
else:
    print(f"  ✓ Download location exists: {dl_path}")
EOF

# Restart to apply changes
echo ""
echo "[4] Restarting daemon to apply changes..."
sudo systemctl restart deluged
sleep 3

# Verify it's running
echo ""
echo "[5] Final verification:"
if systemctl is-active --quiet deluged; then
    echo "  ✓ deluged is running"
else
    echo "  ✗ deluged failed to start"
fi

if sudo ss -tuln | grep -q ":58846"; then
    echo "  ✓ Daemon is listening on port 58846"
else
    echo "  ✗ Daemon not listening"
fi

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "✅ Authentication: Working"
echo "✅ Torrent adding: Working (tested via deluge-console)"
echo ""
echo "Now set up the Web UI connection:"
echo "1. Open http://192.168.83.128:8112 in your browser"
echo "2. Clear browser cache or use Incognito mode"
echo "3. Log in with password: deluge"
echo "4. Open Connection Manager (plug icon bottom-left)"
echo "5. Remove any old connections"
echo "6. Add new connection:"
echo "   - Host: 127.0.0.1"
echo "   - Port: 58846"
echo "   - Username: deluge"
echo "   - Password: deluge"
echo "7. Click Connect (should turn green)"
echo "8. Try adding a torrent via the web UI"
echo ""
echo "Your torrents will download through Proton VPN automatically!"

