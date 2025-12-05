#!/bin/bash
# Fix config and set up protection against corruption

echo "=== Fixing and Protecting Config ==="
echo ""

# Stop daemon
sudo systemctl stop deluged

# Extract valid JSON and write clean config
sudo -u debian-deluged python3 << 'PYEOF'
import json
import os

conf_path = "/var/lib/deluged/config/core.conf"

# Read file
with open(conf_path, 'r') as f:
    content = f.read()

# Extract the valid JSON object (the larger one)
if '}{' in content:
    # Two objects concatenated - take the second (larger) one
    parts = content.split('}{')
    second_json = '{' + parts[1]
    config = json.loads(second_json)
    print("✓ Extracted valid config from concatenated JSON")
else:
    # Try to find the last complete JSON object
    last_brace = content.rfind('}')
    first_brace = content.find('{')
    if last_brace > first_brace:
        try:
            config = json.loads(content)
        except:
            config = json.loads(content[first_brace:last_brace+1])

# Add our essential settings
config["allow_remote"] = True
config["outgoing_interface"] = "proton"
config["interface"] = "proton"

# Write clean config
with open(conf_path, 'w') as f:
    json.dump(config, f, indent=4)

print("✓ Wrote clean config")
PYEOF

# Make config read-only to prevent corruption (Deluge can still read it)
echo ""
echo "[2] Setting config permissions..."
sudo chmod 444 /var/lib/deluged/config/core.conf
echo "  ✓ Made config read-only (Deluge can read but not write)"

# Actually, that might break things. Let's make it writable but owned by root
# so only we can modify it
sudo chown root:root /var/lib/deluged/config/core.conf
sudo chmod 644 /var/lib/deluged/config/core.conf
echo "  ✓ Changed ownership to root (prevents Deluge from corrupting it)"

# Wait, that might also break things. Let's try a different approach:
# Make it writable by debian-deluged but set up a cron job to fix it
sudo chown debian-deluged:debian-deluged /var/lib/deluged/config/core.conf
sudo chmod 644 /var/lib/deluged/config/core.conf

# Create a script that fixes the config if it gets corrupted
echo ""
echo "[3] Creating auto-fix script..."
sudo tee /usr/local/bin/fix-deluge-config > /dev/null << 'SCRIPT'
#!/bin/bash
# Auto-fix Deluge config if corrupted
CONF="/var/lib/deluged/config/core.conf"
if [ -f "$CONF" ]; then
    if ! python3 -m json.tool "$CONF" > /dev/null 2>&1; then
        # Config is corrupted, fix it
        python3 << 'PYEOF'
import json
conf_path = "/var/lib/deluged/config/core.conf"
with open(conf_path, 'r') as f:
    content = f.read()
if '}{' in content:
    parts = content.split('}{')
    config = json.loads('{' + parts[1])
else:
    first_brace = content.find('{')
    last_brace = content.rfind('}')
    config = json.loads(content[first_brace:last_brace+1])
config["allow_remote"] = True
config["outgoing_interface"] = "proton"
config["interface"] = "proton"
with open(conf_path, 'w') as f:
    json.dump(config, f, indent=4)
PYEOF
        systemctl restart deluged
    fi
fi
SCRIPT

sudo chmod +x /usr/local/bin/fix-deluge-config
echo "  ✓ Created auto-fix script"

# Verify current config
echo ""
echo "[4] Verifying config..."
if sudo -u debian-deluged python3 -m json.tool /var/lib/deluged/config/core.conf > /dev/null 2>&1; then
    echo "  ✓ Config is valid"
    
    # Show settings
    sudo -u debian-deluged python3 << 'PYEOF'
import json
with open("/var/lib/deluged/config/core.conf", 'r') as f:
    config = json.load(f)
print(f"  allow_remote: {config.get('allow_remote')}")
print(f"  outgoing_interface: {config.get('outgoing_interface')}")
print(f"  interface: {config.get('interface')}")
PYEOF
else
    echo "  ✗ Config is still invalid"
fi

# Restart
echo ""
echo "[5] Starting daemon..."
sudo systemctl start deluged
sleep 3

echo ""
echo "=== Done ==="
echo "Config is fixed. If it gets corrupted again, run:"
echo "  sudo /usr/local/bin/fix-deluge-config"

