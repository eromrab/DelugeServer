#!/bin/bash
# Troubleshoot VMware shared folder mounting

echo "=== Troubleshooting VMware Shared Folder ==="
echo ""

# Check if directory exists
echo "[1] Checking mount point..."
if [ -d "/mnt/hgfs" ]; then
    echo "  ✓ /mnt/hgfs exists"
else
    echo "  ✗ /mnt/hgfs doesn't exist, creating it..."
    sudo mkdir -p /mnt/hgfs
    echo "  ✓ Created"
fi

# Check if VMware Tools is installed
echo ""
echo "[2] Checking VMware Tools..."
if command -v vmware-hgfsclient > /dev/null 2>&1; then
    echo "  ✓ vmware-hgfsclient is available"
    echo "  Available shares:"
    vmware-hgfsclient 2>/dev/null || echo "    (No shares found or not configured)"
else
    echo "  ✗ vmware-hgfsclient not found"
    echo "  Installing open-vm-tools..."
    sudo apt install -y open-vm-tools 2>/dev/null || echo "  (Install failed - network issue)"
fi

# Check if vmhgfs-fuse is available
echo ""
echo "[3] Checking vmhgfs-fuse..."
if command -v vmhgfs-fuse > /dev/null 2>&1; then
    echo "  ✓ vmhgfs-fuse is available"
else
    echo "  ✗ vmhgfs-fuse not found"
    echo "  It should be part of open-vm-tools"
fi

# Try to list shares
echo ""
echo "[4] Listing available shares..."
if command -v vmware-hgfsclient > /dev/null 2>&1; then
    SHARES=$(vmware-hgfsclient 2>/dev/null)
    if [ -n "$SHARES" ]; then
        echo "  Available shares:"
        for share in $SHARES; do
            echo "    - $share"
        done
    else
        echo "  ⚠ No shares found"
        echo "  Make sure:"
        echo "    1. VM is powered off (not suspended)"
        echo "    2. Shared folder is configured in VMware Settings"
        echo "    3. Share is set to 'Always enabled'"
    fi
else
    echo "  ⚠ Cannot check shares (vmware-hgfsclient not available)"
fi

# Try mounting
echo ""
echo "[5] Attempting to mount..."

# First, try to see what shares are available
if command -v vmware-hgfsclient > /dev/null 2>&1; then
    SHARES=$(vmware-hgfsclient 2>/dev/null)
    if [ -n "$SHARES" ]; then
        # Try mounting the first available share
        FIRST_SHARE=$(echo $SHARES | awk '{print $1}')
        echo "  Attempting to mount: $FIRST_SHARE"
        
        # Unmount if already mounted
        sudo umount /mnt/hgfs 2>/dev/null
        
        # Try mounting
        if sudo vmhgfs-fuse .host:/$FIRST_SHARE /mnt/hgfs -o allow_other,uid=$(id -u),gid=$(id -g) 2>&1; then
            echo "  ✓ Mount successful!"
            ls -la /mnt/hgfs/ | head -5
        else
            echo "  ✗ Mount failed"
            echo ""
            echo "  Trying alternative mount method..."
            # Try mounting all shares
            if sudo vmhgfs-fuse .host:/ /mnt/hgfs -o allow_other,uid=$(id -u),gid=$(id -g) 2>&1; then
                echo "  ✓ Mount successful (all shares)"
                ls -la /mnt/hgfs/ | head -5
            else
                echo "  ✗ Alternative mount also failed"
            fi
        fi
    else
        echo "  ⚠ No shares available to mount"
        echo "  Configure shared folder in VMware first"
    fi
else
    echo "  ⚠ Cannot mount (vmware-hgfsclient not available)"
fi

echo ""
echo "=== Summary ==="
echo "If mount failed, check:"
echo "  1. VM was powered off (not suspended) when configuring share"
echo "  2. Share is set to 'Always enabled' in VMware"
echo "  3. VMware Tools is installed: sudo apt install open-vm-tools"
echo "  4. Try rebooting the VM after configuring the share"

