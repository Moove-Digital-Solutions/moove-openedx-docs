#!/bin/bash
# ============================================================================
# Safe Server Cleanup Script for Open edX (Tutor) on Ubuntu
# Run as root or with sudo
# ============================================================================

set -e

echo "================================================================"
echo "     Server Disk Cleanup – Safe Recovery"
echo "================================================================"

# 1. Display current disk usage
echo ""
echo "--- Current Disk Usage ---"
df -h /

# 2. Ask for confirmation if disk usage is below threshold
USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$USAGE" -lt 75 ]; then
    echo "⚠️  Disk usage is ${USAGE}% – cleanup may not be necessary."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# 3. Stop Tutor services (optional – but recommended for safe cleanup)
echo ""
echo "Stopping Tutor services..."
sudo systemctl stop tutor.service 2>/dev/null || echo "Tutor service not running."

# 4. Docker system prune (aggressive but safe)
echo ""
echo "Pruning Docker: images, containers, volumes, build cache..."
docker system prune -a -f --volumes
docker builder prune -a -f

# 5. Clean package manager caches
echo ""
echo "Cleaning APT cache..."
apt clean
apt autoclean
apt autoremove -y

# 6. Remove old kernels (keep current + one previous)
echo ""
echo "Removing old kernels (keeping current + 1 previous)..."
if command -v purge-old-kernels &>/dev/null; then
    purge-old-kernels -q
else
    # Manual kernel removal (Ubuntu)
    current_kernel=$(uname -r)
    kernels=$(dpkg -l | grep linux-image | awk '{print $2}' | grep -v "$current_kernel" | head -n -1)
    if [ -n "$kernels" ]; then
        echo "Removing kernels: $kernels"
        apt purge -y $kernels
    else
        echo "No old kernels to remove."
    fi
fi

# 7. Trim system logs (keep last 3 days)
echo ""
echo "Vacuuming system logs (keep last 3 days)..."
journalctl --vacuum-time=3d

# 8. Remove old rotated logs from /var/log
echo ""
echo "Deleting old compressed log files (*.gz, *.1)..."
find /var/log -type f \( -name "*.gz" -o -name "*.1" \) -delete

# 9. Clean /tmp
echo ""
echo "Cleaning /tmp (excluding system files)..."
rm -rf /tmp/*

# 10. Optional: Remove Tutor's node_modules from failed builds (if any)
if [ -d /opt/tutor-data/env/plugins/mfe/build/mfe/node_modules ]; then
    echo "Removing unused node_modules from MFE build (if present)..."
    rm -rf /opt/tutor-data/env/plugins/mfe/build/mfe/node_modules
fi

# 11. Show freed space
echo ""
echo "--- Freed Space Summary ---"
df -h /
echo ""
echo "✅ Cleanup completed successfully."

# 12. Restart Tutor (optional)
echo ""
read -p "Restart Tutor services now? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo systemctl start tutor.service
    echo "Tutor services restarted."
fi

echo "================================================================"