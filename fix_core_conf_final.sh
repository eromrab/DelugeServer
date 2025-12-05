#!/bin/bash
# Fix corrupted core.conf one final time

echo "=== Fixing Corrupted core.conf ==="
echo ""

# Stop daemon
sudo systemctl stop deluged

# Backup and recreate
sudo -u debian-deluged python3 << 'PYEOF'
import json
import os

conf_path = "/var/lib/deluged/config/core.conf"

# Backup
if os.path.exists(conf_path):
    os.rename(conf_path, conf_path + ".backup." + str(int(os.path.getmtime(conf_path))))

# Create clean minimal config with all essential settings
config = {
    "file": 1,
    "format": 1,
    "allow_remote": True,
    "outgoing_interface": "proton",
    "interface": "proton",
    "download_location": "/var/lib/deluged/Downloads",
    "move_completed_path": "/var/lib/deluged/Downloads/complete",
    "torrentfiles_location": "/var/lib/deluged/Downloads/.torrents",
    "dht": True,
    "pex": True,
    "utp": True,
    "max_connections_global": 200,
    "listen_ports": [6881, 6891],
    "outgoing_ports": [0, 0],
    "random_outgoing_ports": True,
    "max_upload_slots_global": 4,
    "max_connections_per_torrent": 50,
    "max_upload_slots_per_torrent": 4,
    "max_upload_speed": -1.0,
    "max_download_speed": -1.0,
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
    "enc_in_policy": 1,
    "enc_out_policy": 1,
    "enc_level": 2,
    "prioritize_first_last_pieces": False,
    "pre_allocate_storage": False,
    "compact_allocation": False,
    "move_completed": False,
    "upnp": False,
    "natpmp": False,
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

print("✓ Created clean core.conf")
print("  - allow_remote: True")
print("  - outgoing_interface: proton")
print("  - interface: proton")
print("  - download_location: /var/lib/deluged/Downloads")
PYEOF

# Create download directories
sudo mkdir -p /var/lib/deluged/Downloads /var/lib/deluged/Downloads/complete /var/lib/deluged/Downloads/.torrents
sudo chown -R debian-deluged:debian-deluged /var/lib/deluged

# Verify JSON is valid
echo ""
echo "[2] Verifying JSON is valid..."
sudo -u debian-deluged python3 -m json.tool /var/lib/deluged/config/core.conf > /dev/null && echo "  ✓ JSON is valid" || echo "  ✗ JSON is invalid"

# Restart
echo ""
echo "[3] Starting daemon..."
sudo systemctl start deluged
sleep 3

# Verify
echo ""
echo "[4] Verification:"
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

echo ""
echo "=== Done ==="
echo "Config is now clean and VPN binding is set."
echo "Try connecting via web UI now!"

