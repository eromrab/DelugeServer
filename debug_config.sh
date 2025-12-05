#!/bin/bash
# Debug why config keeps getting corrupted

echo "=== Debugging Config File ==="
echo ""

# Check the actual file contents
echo "[1] Raw file contents (first 20 lines):"
sudo -u debian-deluged head -20 /var/lib/deluged/config/core.conf

echo ""
echo "[2] File size and permissions:"
ls -lh /var/lib/deluged/config/core.conf

echo ""
echo "[3] Checking for non-printable characters:"
sudo -u debian-deluged cat /var/lib/deluged/config/core.conf | od -c | head -20

echo ""
echo "[4] Trying to parse with Python to see exact error:"
sudo -u debian-deluged python3 << 'EOF'
import json
try:
    with open("/var/lib/deluged/config/core.conf", 'r') as f:
        content = f.read()
    print(f"File length: {len(content)} characters")
    print(f"First 200 chars: {repr(content[:200])}")
    print("\nTrying to parse...")
    config = json.loads(content)
    print("✓ Successfully parsed!")
except json.JSONDecodeError as e:
    print(f"✗ JSON Error: {e}")
    print(f"Error at position: {e.pos}")
    print(f"Context around error:")
    start = max(0, e.pos - 50)
    end = min(len(content), e.pos + 50)
    print(repr(content[start:end]))
EOF

