# Setting Up VMware Shared Folder

## Problem: Options Grayed Out

If the Shared Folders options are grayed out, the VM needs to be **completely shut down**, not just suspended.

## Solution:

### Step 1: Shut Down VM Completely
- **Do NOT** just suspend (pause) the VM
- **Shut down** the VM completely:
  - In Linux VM: `sudo shutdown -h now` or `sudo poweroff`
  - Or in VMware: VM → Power → Shut Down Guest
  - Wait until the VM is fully powered off (not suspended)

### Step 2: Configure Shared Folder in VMware
1. With VM **powered off**, go to: **VM → Settings → Options → Shared Folders**
2. Select **"Always enabled"** (not "Enabled until next power off")
3. Click **"Add..."** button
4. Browse to your Windows folder (e.g., `C:\Shared\GitHub`)
5. Give it a name (e.g., `GitHub`)
6. Check **"Enable this share"**
7. Click **OK**

### Step 3: Start VM and Mount in Linux
Once the VM is started again, run these commands in your Debian VM:

```bash
# Install VMware Tools (if not already installed)
sudo apt update
sudo apt install -y open-vm-tools open-vm-tools-desktop

# Create mount point
sudo mkdir -p /mnt/hgfs

# Mount the shared folder
sudo vmhgfs-fuse .host:/GitHub /mnt/hgfs -o allow_other,uid=$(id -u),gid=$(id -g)

# Verify it's mounted
ls -la /mnt/hgfs/
```

### Step 4: Make It Permanent (Optional)
To mount automatically on boot, add to `/etc/fstab`:

```bash
echo ".host:/GitHub /mnt/hgfs fuse.vmhgfs-fuse allow_other,uid=$(id -u),gid=$(id -g),defaults 0 0" | sudo tee -a /etc/fstab
```

## Troubleshooting:

**If options are still grayed out:**
- Make sure VM is **completely powered off** (not suspended)
- Try closing and reopening VMware Settings
- Check if VMware Tools are installed on the host

**If mount fails:**
- Verify VMware Tools are installed: `sudo apt install open-vm-tools`
- Check if the share name matches: `sudo vmhgfs-fuse .host:/ /mnt/hgfs -o allow_other`
- List available shares: `vmware-hgfsclient`

**If you see "command not found":**
```bash
sudo apt install open-vm-tools open-vm-tools-desktop
sudo reboot
```

