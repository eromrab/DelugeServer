# Deluge Torrent Adding Issue - Manual Fix Guide

## Problem Summary
Based on your conversation, torrents aren't appearing in the list after clicking "Add". The most likely cause is that `core.conf` was corrupted when `allow_remote: true` was appended as plain text to a JSON file.

## Quick Diagnostic Commands

Run these on your Debian VM to check the current state:

```bash
# 1. Check if services are running
sudo systemctl status deluged deluge-web

# 2. Check if daemon is listening
sudo ss -tuln | grep 58846

# 3. Check if core.conf is valid JSON
sudo -u deluge python3 -m json.tool /var/lib/deluge/.config/deluge/core.conf

# 4. Check recent errors
sudo journalctl -u deluged -n 30 --no-pager
sudo journalctl -u deluge-web -n 30 --no-pager
```

## The Fix (Step by Step)

### Step 1: Stop Services
```bash
sudo systemctl stop deluged deluge-web
```

### Step 2: Fix core.conf (Most Important!)

The `core.conf` file is JSON, but `allow_remote: true` was appended as plain text, breaking the JSON format.

**Option A: Use Python to fix it properly**
```bash
sudo -u deluge python3 << 'EOF'
import json
import os

conf_path = "/var/lib/deluge/.config/deluge/core.conf"

# Read the file
with open(conf_path, 'r') as f:
    content = f.read()

# Remove any non-JSON lines (like "allow_remote: true" that was appended)
lines = content.split('\n')
json_lines = []
for line in lines:
    # Stop at first plain text line
    if ':' in line and not ('"' in line or '{' in line or '}' in line or '[' in line or ']' in line or line.strip().startswith('//')):
        stripped = line.strip()
        if stripped and not (stripped.startswith('{') or stripped.startswith('}') or stripped.startswith('"') or stripped.startswith(',') or stripped.startswith('[') or stripped.startswith(']')):
            # This looks like plain text, skip it
            break
    json_lines.append(line)

# Join and parse
json_content = '\n'.join(json_lines)
try:
    config = json.loads(json_content)
except json.JSONDecodeError as e:
    print(f"JSON Error: {e}")
    print("Trying to fix common issues...")
    # Try removing trailing commas
    json_content = json_content.replace(',\n}', '\n}').replace(',\n]', '\n]')
    config = json.loads(json_content)

# Add allow_remote properly
config["allow_remote"] = True

# Ensure interface binding is set
if "outgoing_interface" not in config:
    config["outgoing_interface"] = "proton"
if "interface" not in config:
    config["interface"] = "proton"

# Write back
with open(conf_path, 'w') as f:
    json.dump(config, f, indent=4)

print("✓ Fixed core.conf")
EOF
```

**Option B: If Python fix doesn't work, regenerate config**
```bash
# Backup current config
sudo -u deluge cp /var/lib/deluge/.config/deluge/core.conf /var/lib/deluge/.config/deluge/core.conf.backup

# Remove the broken config
sudo -u deluge rm /var/lib/deluge/.config/deluge/core.conf

# Start deluged once to regenerate default config
sudo -u deluge deluged
sleep 3
sudo pkill -u deluge deluged

# Now edit the new config properly
sudo -u deluge python3 << 'EOF'
import json

conf_path = "/var/lib/deluge/.config/deluge/core.conf"
with open(conf_path, 'r') as f:
    config = json.load(f)

config["allow_remote"] = True
config["outgoing_interface"] = "proton"
config["interface"] = "proton"

with open(conf_path, 'w') as f:
    json.dump(config, f, indent=4)
print("✓ Created new core.conf with proper settings")
EOF
```

### Step 3: Verify Auth File
```bash
# Check if auth file exists and is correct
sudo -u deluge cat /var/lib/deluge/.config/deluge/auth

# If it doesn't exist or is wrong:
echo "deluge:deluge:10" | sudo -u deluge tee /var/lib/deluge/.config/deluge/auth
sudo chown deluge:deluge /var/lib/deluge/.config/deluge/auth
sudo chmod 600 /var/lib/deluge/.config/deluge/auth
```

### Step 4: Reset Web UI Config
```bash
# Remove web UI config to force fresh connection
sudo -u deluge rm -f /var/lib/deluge/.config/deluge/web.conf
```

### Step 5: Restart Services
```bash
sudo systemctl start deluged deluge-web
sleep 3

# Verify they're running
sudo systemctl status deluged --no-pager | head -10
sudo systemctl status deluge-web --no-pager | head -10
```

### Step 6: Test Connection
```bash
# Check if daemon is listening
sudo ss -tuln | grep 58846

# Should show something like:
# tcp LISTEN 0 128 127.0.0.1:58846 0.0.0.0:*
```

## Browser Steps (Critical!)

After running the commands above:

1. **Open** http://192.168.83.128:8112
2. **Clear browser cache** (Ctrl+Shift+Delete) or use Incognito/Private mode
3. **Log in** with password: `deluge`
4. **Open Connection Manager** (plug icon in bottom-left corner)
5. **Remove ALL existing connections** (click the red minus button)
6. **Add new connection:**
   - Click green **+** button
   - Host: `localhost` (or `127.0.0.1`)
   - Port: `58846`
   - Username: `deluge` (or leave blank)
   - Password: `deluge`
   - Click **Add**
7. **Select the connection** and click **Connect** (should turn green)
8. **Close** Connection Manager
9. **Try adding a torrent** using the **+** button

## If It Still Doesn't Work

### Check Logs for Errors
```bash
# Deluge daemon logs
sudo journalctl -u deluged -n 50 --no-pager | grep -i error

# Web UI logs  
sudo journalctl -u deluge-web -n 50 --no-pager | grep -i error

# Check if daemon is actually running
ps aux | grep deluged | grep -v grep
```

### Verify core.conf is Valid
```bash
sudo -u deluge python3 -m json.tool /var/lib/deluge/.config/deluge/core.conf | head -20
```

If this command fails, the JSON is still broken and needs to be fixed.

### Test Direct Connection
```bash
# Try connecting via deluge-console (if installed)
sudo apt install deluge-console -y
sudo -u deluge deluge-console "connect localhost:58846 deluge deluge; info"
```

## Common Issues

1. **"allow_remote" not set properly** - Must be JSON boolean `true`, not plain text
2. **Auth file missing or wrong format** - Should be `username:password:level` (e.g., `deluge:deluge:10`)
3. **Web UI cached old connection** - Clear browser cache or use private mode
4. **Daemon not listening** - Check if deluged service is actually running
5. **Permission issues** - All config files must be owned by `deluge:deluge`

## Success Indicators

You'll know it's working when:
- Connection Manager shows green "Online" status
- Adding a torrent makes it appear in the list within 5-10 seconds
- Torrent shows "Downloading metadata..." or starts downloading
- No errors in `journalctl -u deluged`

