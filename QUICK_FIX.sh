#!/bin/bash
# Quick fix for corrupted Deluge core.conf
# Copy and paste this entire block into your Debian VM terminal

set -e

echo "=== Fixing Deluge core.conf ==="

# Stop services
echo "[1/5] Stopping services..."
sudo systemctl stop deluged deluge-web

# Backup existing config
echo "[2/5] Backing up existing config..."
sudo -u deluge cp /var/lib/deluge/.config/deluge/core.conf /var/lib/deluge/.config/deluge/core.conf.backup.$(date +%s) 2>/dev/null || true

# Create a clean config using Python
echo "[3/5] Creating clean core.conf..."
sudo -u deluge python3 << 'PYEOF'
import json
import os

config = {
    "file": 1,
    "format": 1,
    "info_sent": 0.0,
    "lsd": True,
    "max_connections_global": 200,
    "send_info": False,
    "move_completed_path": "/var/lib/deluge/completed",
    "download_location": "/var/lib/deluge/downloads",
    "torrentfiles_location": "/var/lib/deluge/torrents",
    "move_completed": False,
    "max_upload_slots_global": 4,
    "listen_ports": [6881, 6891],
    "outgoing_ports": [0, 0],
    "random_outgoing_ports": True,
    "listen_interface": "",
    "outgoing_interface": "proton",
    "interface": "proton",
    "allow_remote": True,
    "dht": True,
    "upnp": False,
    "natpmp": False,
    "utp": True,
    "pex": True,
    "enc_in_policy": 1,
    "enc_out_policy": 1,
    "enc_level": 2,
    "max_connections_per_torrent": 50,
    "max_upload_slots_per_torrent": 4,
    "max_upload_speed": -1.0,
    "max_download_speed": -1.0,
    "max_download_speed_per_torrent": -1.0,
    "max_upload_speed_per_torrent": -1.0,
    "prioritize_first_last_pieces": False,
    "pre_allocate_storage": False,
    "compact_allocation": False,
    "auto_managed": True,
    "stop_seed_at_ratio": False,
    "stop_seed_ratio": 2.0,
    "remove_seed_at_ratio": False,
    "share_ratio_limit": 2.0,
    "share_time_ratio_limit": 7.0,
    "share_time_limit": 180,
    "seed_time_ratio_limit": 7.0,
    "seed_time_limit": 180,
    "queue_new_to_top": False,
    "ignore_limits_on_local_network": True,
    "rate_limit_ip_overhead": True,
    "announce_to_all_tiers": True,
    "announce_to_all_trackers": False,
    "max_connections_per_second": 50,
    "listen_random_port": False,
    "max_half_open_connections": 50,
    "proxy": {
        "type": 0,
        "hostname": "",
        "username": "",
        "password": "",
        "port": 8080,
        "peer_connections": True,
        "force_proxy": False,
        "anonymous_mode": False
    }
}

conf_path = "/var/lib/deluge/.config/deluge/core.conf"
with open(conf_path, 'w') as f:
    json.dump(config, f, indent=4)

print("✓ Created clean core.conf")
print("  - allow_remote: True")
print("  - outgoing_interface: proton")
print("  - interface: proton")
PYEOF

# Ensure auth file exists
echo "[4/5] Checking auth file..."
if [ ! -f /var/lib/deluge/.config/deluge/auth ]; then
    echo "deluge:deluge:10" | sudo -u deluge tee /var/lib/deluge/.config/deluge/auth > /dev/null
    sudo chmod 600 /var/lib/deluge/.config/deluge/auth
    echo "✓ Created auth file"
else
    echo "✓ Auth file exists"
fi

# Restart services
echo "[5/5] Restarting services..."
sudo systemctl start deluged deluge-web
sleep 2

# Verify
echo ""
echo "=== Verification ==="
if sudo systemctl is-active --quiet deluged; then
    echo "✓ deluged is running"
else
    echo "✗ deluged failed to start - check logs: sudo journalctl -u deluged -n 20"
fi

if sudo systemctl is-active --quiet deluge-web; then
    echo "✓ deluge-web is running"
else
    echo "✗ deluge-web failed to start - check logs: sudo journalctl -u deluge-web -n 20"
fi

if sudo ss -tuln | grep -q ":58846"; then
    echo "✓ Daemon is listening on port 58846"
else
    echo "⚠ Daemon may not be listening yet (wait a few seconds)"
fi

echo ""
echo "=== Next Steps ==="
echo "1. Open http://192.168.83.128:8112 in your browser"
echo "2. Clear browser cache or use Incognito mode"
echo "3. Log in with password: deluge"
echo "4. Open Connection Manager (plug icon bottom-left)"
echo "5. Remove old connection, add new:"
echo "   - Host: localhost"
echo "   - Port: 58846"
echo "   - Username: deluge"
echo "   - Password: deluge"
echo "6. Connect and try adding a torrent"

