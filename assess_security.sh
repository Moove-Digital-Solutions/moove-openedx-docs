#!/bin/bash
# Comprehensive Security Assessment Script for Moove Education Platform
# Run with sudo
# Version: 2.0 (CMCSRS Compliant)

echo "=========================================="
echo " Moove Education Platform Security Audit"
echo " Date: $(date)"
echo " Version: 2.0"
echo "=========================================="

# 1. System and OS
echo -e "\n--- OS and Kernel ---"
uname -a
lsb_release -d
hostnamectl

# 2. Users and Groups
echo -e "\n--- Users with sudo/root ---"
grep -E "^sudo|^root" /etc/group
echo -e "\n--- Tutor user existence ---"
id tutor 2>/dev/null || echo "⚠️ User 'tutor' does not exist (CRIT-01)"

# 3. Firewall Status
echo -e "\n--- UFW Status (CRIT-02) ---"
ufw status verbose 2>/dev/null || echo "⚠️ UFW not active"

# 4. Listening Ports
echo -e "\n--- Open Ports (LISTEN) ---"
ss -tulpn | grep LISTEN | grep -v "127.0.0.1"

# 5. Docker Security
echo -e "\n--- Docker Daemon User ---"
ps aux | grep dockerd | grep -v grep
echo -e "\n--- Running Containers with Privileged Flags ---"
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Command}}" | grep -i privileged || echo "None"

# 6. Secrets in Config (masked output)
echo -e "\n--- Tutor Config (secrets masked) ---"
grep -E "PASSWORD|SECRET|KEY" /root/.local/share/tutor-main/config.yml | sed 's/=.*/=***MASKED***/'

# 7. File Permissions
echo -e "\n--- Critical File Permissions ---"
ls -la /root/.local/share/tutor-main/config.yml
ls -la /etc/nginx/sites-available/ 2>/dev/null || echo "Nginx config not found"

# 8. Logs (last 10 lines of critical logs)
echo -e "\n--- Recent Syslog Errors ---"
tail -20 /var/log/syslog | grep -i error
echo -e "\n--- Tutor Container Logs (last 5 lines each) ---"
for c in lms cms mfe mysql mongodb redis meilisearch; do
    echo ">>> $c <<<"
    docker logs --tail=5 tutor_main_local-$c 2>/dev/null || echo "Container not found"
done

# 9. Vulnerability Scan
if command -v trivy &>/dev/null; then
    echo -e "\n--- Container Image Vulnerabilities (summary) ---"
    trivy image --severity HIGH,CRITICAL --light overhangio/openedx:21.0.7-main-indigo 2>/dev/null | tail -10
else
    echo "⚠️ Trivy not installed; skipping image scan (HIGH-08)"
fi

# 10. Backup Status
echo -e "\n--- Recent Backup Files (last 7 days) ---"
find /root -name "*.sql" -o -name "*.tar.gz" -mtime -7 2>/dev/null

# 11. Security Headers Check (CMCSRS 5.7.c)
echo -e "\n--- Security Headers ---"
curl -sI https://educationvirtual.net | grep -i "x-frame-options\|x-content-type-options\|strict-transport\|x-xss-protection"

# 12. Fail2ban Status (HIGH-06)
echo -e "\n--- Fail2ban Status ---"
systemctl status fail2ban 2>/dev/null || echo "⚠️ Fail2ban not installed"

# 13. Kernel Versions (HIGH-04)
echo -e "\n--- Installed Kernels ---"
dpkg -l | grep linux-image | awk '{print $2, $3}'

# 14. Memory Usage (CRIT-07)
echo -e "\n--- Memory Usage (RAM + Swap) ---"
free -h

# 15. Container Health Checks (MED-02)
echo -e "\n--- Container Health Status ---"
docker ps --format "table {{.Names}}\t{{.Status}}"

echo -e "\n=========================================="
echo " Audit complete. Findings marked with ⚠️"
echo "=========================================="