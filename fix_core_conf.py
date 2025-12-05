#!/usr/bin/env python3
"""
Robust fix for corrupted Deluge core.conf file
This script can handle severely corrupted JSON and regenerate if needed
"""
import json
import sys
import os
import shutil
from pathlib import Path

conf_path = "/var/lib/deluge/.config/deluge/core.conf"
backup_path = f"{conf_path}.backup.{os.getpid()}"

def try_fix_json():
    """Try to fix the existing JSON file"""
    print("Attempting to fix existing core.conf...")
    
    with open(conf_path, 'r') as f:
        content = f.read()
    
    # Strategy 1: Find the last valid closing brace
    lines = content.split('\n')
    json_lines = []
    brace_count = 0
    in_string = False
    escape_next = False
    
    for i, line in enumerate(lines):
        if escape_next:
            escape_next = False
            continue
            
        # Simple check: stop at lines that look like plain text config
        stripped = line.strip()
        if stripped and not stripped.startswith('{') and not stripped.startswith('}') and not stripped.startswith('"') and not stripped.startswith('//') and not stripped.startswith(',') and not stripped.startswith('[') and not stripped.startswith(']'):
            # Check if it looks like "key: value" (plain text, not JSON)
            if ':' in stripped and not ('"' in stripped or '{' in stripped):
                print(f"  Found plain text at line {i+1}: {stripped[:50]}")
                break
        
        json_lines.append(line)
        
        # Count braces to find where JSON might end
        for char in line:
            if escape_next:
                escape_next = False
                continue
            if char == '\\':
                escape_next = True
                continue
            if char == '"' and not escape_next:
                in_string = not in_string
            if not in_string:
                if char == '{':
                    brace_count += 1
                elif char == '}':
                    brace_count -= 1
    
    json_content = '\n'.join(json_lines)
    
    # Try to parse
    try:
        # Remove trailing commas before closing braces/brackets
        import re
        json_content = re.sub(r',(\s*[}\]])', r'\1', json_content)
        
        config = json.loads(json_content)
        print("  ✓ Successfully parsed JSON")
        return config
    except json.JSONDecodeError as e:
        print(f"  ✗ Still invalid JSON: {e}")
        return None

def regenerate_config():
    """Regenerate config from scratch with proper defaults"""
    print("Regenerating core.conf from scratch...")
    
    # Default Deluge config structure
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
        "lsd": True,
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
        "ignore_limits_on_local_network": True,
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
    
    return config

def main():
    # Backup original
    if os.path.exists(conf_path):
        shutil.copy2(conf_path, backup_path)
        print(f"Backed up original to: {backup_path}")
    
    config = None
    
    # Try to fix existing
    if os.path.exists(conf_path):
        config = try_fix_json()
    
    # If fix failed, regenerate
    if config is None:
        config = regenerate_config()
    else:
        # Ensure required settings are present
        config["allow_remote"] = True
        if "outgoing_interface" not in config or not config["outgoing_interface"]:
            config["outgoing_interface"] = "proton"
        if "interface" not in config or not config["interface"]:
            config["interface"] = "proton"
        if "download_location" not in config or not config["download_location"]:
            config["download_location"] = "/var/lib/deluge/downloads"
    
    # Write the fixed config
    with open(conf_path, 'w') as f:
        json.dump(config, f, indent=4)
    
    print(f"✓ Successfully wrote fixed core.conf")
    print(f"  - allow_remote: {config.get('allow_remote')}")
    print(f"  - outgoing_interface: {config.get('outgoing_interface')}")
    print(f"  - interface: {config.get('interface')}")
    print(f"  - download_location: {config.get('download_location')}")

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

