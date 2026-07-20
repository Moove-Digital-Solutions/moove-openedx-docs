#!/bin/bash
# VPS Health Check Script - Storage, Memory, and Recommendations
# Run as root or with sudo

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}     VPS Health Check Report           ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# ---- System Info ----
echo -e "${YELLOW}--- System Information ---${NC}"
echo "Hostname: $(hostname)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p)"
echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
echo ""

# ---- Memory Usage ----
echo -e "${YELLOW}--- Memory Usage (RAM + Swap) ---${NC}"
free -h
echo ""
echo -e "${YELLOW}--- Top 10 Memory-Consuming Processes ---${NC}"
ps aux --sort=-%mem | head -11 | awk '{print $2, $4, $11}' | column -t
echo ""

# ---- CPU Usage ----
echo -e "${YELLOW}--- CPU Info & Top CPU Processes ---${NC}"
lscpu | grep "Model name" | head -1
echo "CPU Cores: $(nproc)"
echo ""
echo -e "${YELLOW}--- Top 10 CPU-Consuming Processes ---${NC}"
ps aux --sort=-%cpu | head -11 | awk '{print $2, $3, $11}' | column -t
echo ""

# ---- Disk Storage Overview ----
echo -e "${YELLOW}--- Disk Partition Usage (df -h) ---${NC}"
df -h
echo ""

echo -e "${YELLOW}--- Inode Usage (df -i) ---${NC}"
df -i
echo ""

# ---- Largest Directories (top 20) ----
echo -e "${YELLOW}--- Top 20 Largest Directories (root filesystem) ---${NC}"
echo "This may take a moment..."
sudo du -hx / 2>/dev/null | sort -hr | head -20
echo ""

# ---- Largest Files (> 100 MB) ----
echo -e "${YELLOW}--- Largest Files (>100 MB) ---${NC}"
sudo find / -type f -size +100M -exec ls -lh {} \; 2>/dev/null | awk '{print $5, $9}' | sort -hr | head -20
echo ""

# ---- Log File Sizes ----
echo -e "${YELLOW}--- Log Directory Sizes (/var/log) ---${NC}"
du -sh /var/log/* 2>/dev/null | sort -hr | head -10
echo ""

# ---- Package Manager Cache ----
echo -e "${YELLOW}--- Package Manager Cache Size ---${NC}"
if command -v apt &>/dev/null; then
    echo "APT cache: $(du -sh /var/cache/apt/archives 2>/dev/null | awk '{print $1}')"
elif command -v yum &>/dev/null; then
    echo "YUM cache: $(du -sh /var/cache/yum 2>/dev/null | awk '{print $1}')"
elif command -v dnf &>/dev/null; then
    echo "DNF cache: $(du -sh /var/cache/dnf 2>/dev/null | awk '{print $1}')"
else
    echo "Package manager not recognized or cache not found."
fi
echo ""

# ---- Old Kernels (Debian/Ubuntu) ----
if command -v dpkg &>/dev/null; then
    echo -e "${YELLOW}--- Installed Kernels (Debian/Ubuntu) ---${NC}"
    dpkg -l | grep linux-image | awk '{print $2, $3}'
    echo "Consider removing old kernels with: sudo apt autoremove --purge"
elif command -v rpm &>/dev/null; then
    echo -e "${YELLOW}--- Installed Kernels (RHEL/CentOS) ---${NC}"
    rpm -qa kernel
    echo "Consider removing old kernels with: sudo package-cleanup --oldkernels --count=2"
fi
echo ""

# ---- Docker (if installed) ----
if command -v docker &>/dev/null; then
    echo -e "${YELLOW}--- Docker Disk Usage ---${NC}"
    docker system df
    echo ""
fi

# ---- Recommendations ----
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}     Recommendations                    ${NC}"
echo -e "${GREEN}========================================${NC}"

# Check disk usage > 80%
THRESHOLD=80
df -h | awk -v threshold=$THRESHOLD '{ if (NR>1 && $5+0 > threshold) print $6 " is at " $5 " usage." }' | while read line; do
    echo -e "${RED}⚠️  $line${NC}"
done

# Check if swap is used heavily
SWAP_USED=$(free | grep Swap | awk '{print $3}')
if [ "$SWAP_USED" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Swap is being used (${SWAP_USED} KB). Consider adding more RAM or optimizing services.${NC}"
fi

# Check for large log files
LARGE_LOGS=$(sudo find /var/log -type f -size +500M 2>/dev/null | wc -l)
if [ "$LARGE_LOGS" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Large log files found (>500 MB). Consider log rotation or truncation.${NC}"
fi

# Check for old kernels
if command -v dpkg &>/dev/null; then
    KERNEL_COUNT=$(dpkg -l | grep linux-image | wc -l)
    if [ "$KERNEL_COUNT" -gt 2 ]; then
        echo -e "${YELLOW}⚠️  Multiple kernels installed (${KERNEL_COUNT}). Run 'sudo apt autoremove --purge' to clean.${NC}"
    fi
fi

# Check for unused packages (Debian/Ubuntu)
if command -v deborphan &>/dev/null; then
    ORPHANS=$(deborphan | wc -l)
    if [ "$ORPHANS" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  ${ORPHANS} orphaned packages found. Consider removing them with 'sudo apt autoremove'.${NC}"
    fi
fi

echo ""
echo -e "${GREEN}Report complete. For further analysis, consider installing:${NC}"
echo "  - ncdu   (interactive disk usage)"
echo "  - iotop  (I/O monitoring)"
echo "  - htop   (better process viewer)"
echo "  - iftop  (network bandwidth)"
echo ""
