#!/bin/bash
# Find where Deluge is actually looking for config files

echo "=== Finding Deluge Configuration Location ==="
echo ""

# Check where deluged process is running from
echo "[1] Deluged process info:"
if pgrep -u deluge deluged > /dev/null; then
    PID=$(pgrep -u deluge deluged)
    echo "  PID: $PID"
    echo "  Command: $(ps -p $PID -o cmd=)"
    echo "  Working directory: $(pwdx $PID 2>/dev/null || ls -l /proc/$PID/cwd 2>/dev/null | awk '{print $NF}')"
    echo "  Environment:"
    sudo -u deluge cat /proc/$PID/environ 2>/dev/null | tr '\0' '\n' | grep -E "(HOME|DELUGE|CONFIG)" || echo "    (no relevant env vars)"
fi

# Check systemd service file
echo ""
echo "[2] Systemd service configuration:"
if [ -f /lib/systemd/system/deluged.service ]; then
    echo "  Service file: /lib/systemd/system/deluged.service"
    cat /lib/systemd/system/deluged.service | grep -E "(User|ExecStart|WorkingDirectory|Environment)" | head -10
fi

# Check all possible config locations
echo ""
echo "[3] Checking all possible config locations:"
CONFIG_LOCATIONS=(
    "/var/lib/deluge/.config/deluge"
    "/home/deluge/.config/deluge"
    "$(getent passwd deluge | cut -d: -f6)/.config/deluge"
)

for loc in "${CONFIG_LOCATIONS[@]}"; do
    if [ -d "$loc" ]; then
        echo "  Found: $loc"
        echo "    Files:"
        ls -la "$loc" 2>/dev/null | head -5
        if [ -f "$loc/auth" ]; then
            echo "    Auth file contents: $(cat "$loc/auth" 2>/dev/null)"
        fi
    fi
done

# Check if Deluge has a --config option or environment variable
echo ""
echo "[4] Checking Deluge command line options:"
if command -v deluged > /dev/null 2>&1; then
    deluged --help 2>&1 | grep -i -E "(config|home|data)" | head -5
fi

# Check Python Deluge module location
echo ""
echo "[5] Python Deluge module info:"
python3 -c "import deluge.config; print(deluge.config.get_config_dir())" 2>/dev/null || echo "  Cannot determine via Python"

# Try to see what the running daemon thinks its config dir is
echo ""
echo "[6] Checking running daemon's view:"
if pgrep -u deluge deluged > /dev/null; then
    # Try to get config via deluge-console if possible, or check process
    echo "  Process file descriptors (might show open files):"
    sudo ls -l /proc/$(pgrep -u deluge deluged)/fd/ 2>/dev/null | grep -E "(auth|config)" | head -5 || echo "    (cannot access)"
fi

echo ""
echo "=== Alternative: Check if auth is disabled ==="
echo "Some Deluge versions might have auth disabled by default."
echo "Check core.conf for:"
sudo -u deluge grep -i auth /var/lib/deluge/.config/deluge/core.conf 2>/dev/null || echo "  (no auth settings found)"

