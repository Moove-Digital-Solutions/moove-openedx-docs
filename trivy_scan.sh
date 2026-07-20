#!/bin/bash
set -euo pipefail

DATE=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="/var/log/trivy"
mkdir -p "$REPORT_DIR"

echo "===== Trivy scan started at $(date) ====="

# ----------------------------------------------------------------------
# 1. Host filesystem scan – all options on one line
# ----------------------------------------------------------------------
FS_REPORT="$REPORT_DIR/trivy_fs_$DATE.txt"
echo "Scanning host filesystem (HIGH/CRITICAL, ignoring unfixed)..."

trivy fs / --severity HIGH,CRITICAL --ignore-unfixed --skip-dirs /var/lib/apt/lists,/var/lib/containerd,/var/lib/docker,/openedx/dist,/tmp,/var/tmp --scanners vuln --timeout 30m > "$FS_REPORT" 2>&1

if [ $? -eq 0 ]; then
    echo "Filesystem scan completed."
else
    echo "WARNING: Filesystem scan exited with code $? (check report)."
fi

# ----------------------------------------------------------------------
# 2. Docker images scan
# ----------------------------------------------------------------------
IMAGES_REPORT="$REPORT_DIR/trivy_images_$DATE.txt"
echo "Scanning Docker images..."

docker images --format "{{.Repository}}:{{.Tag}}" | grep -v '<none>' | while read -r img; do
    echo "===== Scanning $img =====" >> "$IMAGES_REPORT"
    trivy image --severity HIGH,CRITICAL --ignore-unfixed --timeout 15m "$img" >> "$IMAGES_REPORT" 2>&1
    echo "--------------------------------------------------" >> "$IMAGES_REPORT"
done

echo "===== Scan finished at $(date) ====="
echo "Reports saved in $REPORT_DIR"