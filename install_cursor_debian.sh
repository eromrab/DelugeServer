#!/bin/bash
# Install Cursor AI on Debian Linux
# Note: This requires a desktop environment (GUI)

echo "=== Installing Cursor AI on Debian ==="
echo ""

# Check if running in GUI environment
if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
    echo "⚠ Warning: No display detected. Cursor requires a GUI."
    echo "  This script is for systems with a desktop environment."
    echo "  If you're on a headless server, Cursor won't work."
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Download Cursor
echo "[1] Downloading Cursor..."
cd /tmp

# Get the latest .deb package URL (you may need to check cursor.sh for the latest)
# This is an example - check https://cursor.sh for the actual download link
CURSOR_URL="https://downloader.cursor.sh/linux/appImage/x64"
CURSOR_DEB_URL="https://downloader.cursor.sh/linux/deb"

# Try to download .deb package
if command -v wget > /dev/null; then
    echo "  Attempting to download .deb package..."
    wget -O cursor.deb "$CURSOR_DEB_URL" 2>&1 | tail -1
elif command -v curl > /dev/null; then
    echo "  Attempting to download .deb package..."
    curl -L -o cursor.deb "$CURSOR_DEB_URL"
else
    echo "  ✗ Neither wget nor curl found. Install one first:"
    echo "    sudo apt install wget"
    exit 1
fi

# Check if download was successful
if [ ! -f cursor.deb ] || [ ! -s cursor.deb ]; then
    echo "  ⚠ Direct download failed. Please:"
    echo "  1. Visit https://cursor.sh"
    echo "  2. Download the .deb package for Linux"
    echo "  3. Transfer it to this machine"
    echo "  4. Run: sudo dpkg -i /path/to/cursor.deb"
    exit 1
fi

# Install dependencies
echo ""
echo "[2] Installing dependencies..."
sudo apt update
sudo apt install -y libfuse2 libnss3 libatk-bridge2.0-0 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1 libasound2

# Install the .deb package
echo ""
echo "[3] Installing Cursor..."
sudo dpkg -i cursor.deb 2>&1 | grep -v "^\(Preparing\|Unpacking\|Setting up\)"

# Fix any dependency issues
if [ $? -ne 0 ]; then
    echo "  Fixing dependencies..."
    sudo apt install -f -y
fi

# Verify installation
echo ""
echo "[4] Verifying installation..."
if command -v cursor > /dev/null; then
    echo "  ✓ Cursor installed successfully!"
    echo "  Run with: cursor"
else
    echo "  ⚠ Cursor command not found in PATH"
    echo "  Try: /usr/bin/cursor or check installation"
fi

echo ""
echo "=== Installation Complete ==="
echo "Note: Cursor requires a desktop environment to run."
echo "If you're on a headless server, you'll need to:"
echo "  1. Install a desktop environment (GNOME, KDE, XFCE, etc.)"
echo "  2. Or use X11 forwarding if connecting via SSH"
echo "  3. Or install Cursor on your host machine instead"

