#!/bin/bash
# Fix config by letting Deluge create it, then modifying it

echo "=== Fixing Config Properly ==="
echo ""

# Stop daemon
echo "[1] Stopping daemon..."
sudo systemctl stop deluged

# Remove corrupted config
echo "[2] Removing corrupted config..."
sudo rm -f /var/lib/deluged/config/core.conf
sudo rm -f /var/lib/deluged/config/core.conf.backup*

# Start daemon to create fresh config
echo "[3] Starting daemon to create fresh config..."
sudo systemctl start deluged
sleep 5

# Wait for config to be created
echo "[4] Waiting for config to be created..."
for i in {1..10}; do
    if [ -f /var/lib/deluged/config/core.conf ]; then
        echo "  ✓ Config file created"
        break
    fi
    echo "  Waiting... ($i/10)"
    sleep 1
done

# Verify it's valid JSON
echo ""
echo "[5] Verifying config is valid..."
if sudo -u debian-deluged python3 -m json.tool /var/lib/deluged/config/core.conf > /dev/null 2>&1; then
    echo "  ✓ Config is valid JSON"
else
    echo "  ✗ Config is still invalid"
    exit 1
fi

# Now modify it to add our settings
echo ""
echo "[6] Adding VPN binding and allow_remote..."
sudo -u debian-deluged python3 << 'PYEOF'
import json

conf_path = "/var/lib/deluged/config/core.conf"

# Read existing config
with open(conf_path, 'r') as f:
    config = json.load(f)

# Add/modify our settings
config["allow_remote"] = True
config["outgoing_interface"] = "proton"
config["interface"] = "proton"

# Write back
with open(conf_path, 'w') as f:
    json.dump(config, f, indent=4)

print("  ✓ Added VPN binding and allow_remote")
PYEOF

# Verify again
echo ""
echo "[7] Verifying modified config..."
if sudo -u debian-deluged python3 -m json.tool /var/lib/deluged/config/core.conf > /dev/null 2>&1; then
    echo "  ✓ Modified config is still valid"
else
    echo "  ✗ Modified config is invalid"
    exit 1
fi

# Restart to apply
echo ""
echo "[8] Restarting daemon to apply changes..."
sudo systemctl restart deluged
sleep 3

# Final verification
echo ""
echo "[9] Final verification:"
if systemctl is-active --quiet deluged; then
    echo "  ✓ deluged is running"
else
    echo "  ✗ deluged failed to start"
fi

if sudo ss -tuln | grep -q ":58846"; then
    echo "  ✓ Daemon is listening"
else
    echo "  ✗ Daemon not listening"
fi

# Show the settings
echo ""
echo "[10] Current settings:"
sudo -u debian-deluged python3 << 'PYEOF'
import json
with open("/var/lib/deluged/config/core.conf", 'r') as f:
    config = json.load(f)
print(f"  allow_remote: {config.get('allow_remote')}")
print(f"  outgoing_interface: {config.get('outgoing_interface')}")
print(f"  interface: {config.get('interface')}")
PYEOF

echo ""
echo "=== Done ==="
echo "Config is now properly set up. Try connecting via web UI!"

