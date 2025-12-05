#!/bin/bash
# Extract valid JSON from corrupted config file

echo "=== Extracting Valid Config ==="
echo ""

# Stop daemon
sudo systemctl stop deluged

# Extract the second (larger) JSON object which is the real config
sudo -u debian-deluged python3 << 'PYEOF'
import json
import re

conf_path = "/var/lib/deluged/config/core.conf"

# Read the file
with open(conf_path, 'r') as f:
    content = f.read()

# Find all JSON objects in the file
# Look for the pattern: }{ which indicates two objects concatenated
if '}{' in content:
    print("Found concatenated JSON objects")
    # Split on }{ and take the second part (the full config)
    parts = content.split('}{')
    if len(parts) == 2:
        # Reconstruct the second object
        second_json = '{' + parts[1]
        try:
            config = json.loads(second_json)
            print("✓ Successfully extracted second JSON object")
        except:
            # Try to find the largest valid JSON object
            # Look for the last complete JSON object
            brace_count = 0
            start_pos = 0
            for i, char in enumerate(content):
                if char == '{':
                    if brace_count == 0:
                        start_pos = i
                    brace_count += 1
                elif char == '}':
                    brace_count -= 1
                    if brace_count == 0:
                        # Found a complete object
                        try:
                            obj_str = content[start_pos:i+1]
                            config = json.loads(obj_str)
                            print(f"✓ Found valid JSON object at position {start_pos}-{i+1}")
                            break
                        except:
                            continue
    else:
        # Try to parse just the last complete JSON object
        # Find the last { and matching }
        last_open = content.rfind('{')
        if last_open != -1:
            # Find matching closing brace
            brace_count = 0
            for i in range(last_open, len(content)):
                if content[i] == '{':
                    brace_count += 1
                elif content[i] == '}':
                    brace_count -= 1
                    if brace_count == 0:
                        obj_str = content[last_open:i+1]
                        try:
                            config = json.loads(obj_str)
                            print(f"✓ Found valid JSON object")
                            break
                        except:
                            pass
else:
    # Try to parse normally
    try:
        config = json.loads(content)
        print("✓ File is valid JSON")
    except json.JSONDecodeError as e:
        print(f"✗ JSON error: {e}")
        # Try to extract just the first complete object
        # Find first { and matching }
        first_open = content.find('{')
        if first_open != -1:
            brace_count = 0
            for i in range(first_open, len(content)):
                if content[i] == '{':
                    brace_count += 1
                elif content[i] == '}':
                    brace_count -= 1
                    if brace_count == 0:
                        obj_str = content[first_open:i+1]
                        try:
                            config = json.loads(obj_str)
                            print(f"✓ Extracted first valid JSON object")
                            break
                        except:
                            pass

# Add our settings
config["allow_remote"] = True
config["outgoing_interface"] = "proton"
config["interface"] = "proton"

# Write clean config
with open(conf_path, 'w') as f:
    json.dump(config, f, indent=4)

print("✓ Wrote clean config with VPN binding")
PYEOF

# Verify
echo ""
echo "[2] Verifying cleaned config..."
if sudo -u debian-deluged python3 -m json.tool /var/lib/deluged/config/core.conf > /dev/null 2>&1; then
    echo "  ✓ Config is now valid!"
else
    echo "  ✗ Still invalid"
fi

# Restart
echo ""
echo "[3] Restarting daemon..."
sudo systemctl start deluged
sleep 3

echo ""
echo "=== Done ==="

