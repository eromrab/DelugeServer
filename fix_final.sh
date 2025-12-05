#!/bin/bash
# Final fix - correct config location with clean core.conf

echo "=== Final Fix: Correct Config Location ==="
echo ""

# Stop services
sudo systemctl stop deluged deluge-web

# Create auth file in correct location
echo "[1] Creating auth file..."
echo "deluge:deluge:10" | sudo tee /var/lib/deluged/config/auth > /dev/null
sudo chown debian-deluged:debian-deluged /var/lib/deluged/config/auth
sudo chmod 600 /var/lib/deluged/config/auth
echo "  ✓ Auth file created"

# Fix corrupted core.conf
echo ""
echo "[2] Fixing corrupted core.conf..."
sudo -u debian-deluged python3 << 'PYEOF'
import json
import os

conf_path = "/var/lib/deluged/config/core.conf"

# Backup if exists
if os.path.exists(conf_path):
    os.rename(conf_path, conf_path + ".backup")

# Create clean config
config = {
    "file": 1,
    "format": 1,
    "info_sent": 0.0,
    "lsd": True,
    "max_connections_global": 200,
    "send_info": False,
    "move_completed_path": "/var/lib/deluged/Downloads/complete",
    "download_location": "/var/lib/deluged/Downloads",
    "torrentfiles_location": "/var/lib/deluged/Downloads/.torrents",
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

with open(conf_path, 'w') as f:
    json.dump(config, f, indent=4)

print("  ✓ Created clean core.conf")
print("  - allow_remote: True")
print("  - VPN binding: proton")
PYEOF

# Create download directories
echo ""
echo "[3] Creating download directories..."
sudo mkdir -p /var/lib/deluged/Downloads /var/lib/deluged/Downloads/complete /var/lib/deluged/Downloads/.torrents
sudo chown -R debian-deluged:debian-deluged /var/lib/deluged
echo "  ✓ Download directories created"

# Restart
echo ""
echo "[4] Starting services..."
sudo systemctl start deluged
sleep 5

# Verify
echo ""
echo "[5] Verification..."
if systemctl is-active --quiet deluged; then
    echo "  ✓ deluged is running"
else
    echo "  ✗ deluged failed to start"
    sudo journalctl -u deluged -n 10 --no-pager
fi

if sudo ss -tuln | grep -q ":58846"; then
    echo "  ✓ Daemon is listening on port 58846"
else
    echo "  ⚠ Daemon not listening yet"
fi

# Test connection
echo ""
echo "[6] Testing connection..."
if command -v deluge-console > /dev/null 2>&1; then
    timeout 5 sudo -u deluge deluge-console "connect 127.0.0.1:58846 deluge deluge; info" 2>&1 | grep -v "gettext\|bind_textdomain" | head -10
fi

echo ""
echo "=== Done ==="
echo "Config is now in: /var/lib/deluged/config"
echo "Auth file: /var/lib/deluged/config/auth"
echo "Try connecting via web UI or deluge-console now!"

