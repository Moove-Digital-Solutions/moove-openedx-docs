#!/bin/bash
# ============================================================================
# Secure Tutor Environment Information Gatherer
# Run as root (or with sudo) to collect all needed data for CRIT-01 migration.
# Output is masked and saved to /root/tutor_info_$(date +%Y%m%d-%H%M%S).txt
# ============================================================================

set -euo pipefail

REPORT_FILE="/root/tutor_info_$(date +%Y%m%d-%H%M%S).txt"
TUTOR_DEFAULT_ROOT="/root/.local/share/tutor-main"

# ---------- Masking function (Perl preferred, fallback to sed) ----------
mask_sensitive() {
    if command -v perl >/dev/null 2>&1; then
        perl -pe '
            s/(password|secret|key|token|PASS|SECRET|KEY|TOKEN)[:=]\s*\K[^\s,]+/***MASKED***/gi;
            s/(-----BEGIN RSA PRIVATE KEY-----).*?(-----END RSA PRIVATE KEY-----)/$1\n  ***MASKED***\n$2/gs;
        '
    else
        sed -E 's/(password|secret|key|token|PASS|SECRET|KEY|TOKEN)[:=][[:space:]]*[^[:space:]]+/\1=***MASKED***/gi'
    fi
}

# Start fresh report
exec > >(tee -a "$REPORT_FILE") 2>&1

echo "================================================================================"
echo "  TUTOR ENVIRONMENT INFORMATION – FOR CRIT-01 MIGRATION"
echo "  Generated: $(date)"
echo "================================================================================"
echo

# ---------- 1. SYSTEM OVERVIEW ----------
echo "--- 1. SYSTEM OVERVIEW ---"
echo "Hostname: $(hostname -f 2>/dev/null || hostname)"
uname -a
lsb_release -d 2>/dev/null || echo "lsb_release not available"
uptime -p
echo "Load average: $(uptime | awk -F'load average:' '{print $2}')"
echo

# ---------- 2. USER AND GROUP INFORMATION ----------
echo "--- 2. USER AND GROUP INFORMATION ---"
echo "Current user: $(whoami) (UID: $(id -u))"
echo "Groups of current user: $(groups)"
echo
echo "All human users (UID >= 1000):"
awk -F: '$3 >= 1000 {print $1 " (UID:" $3 ")"}' /etc/passwd | sort
echo
echo "System users with shell /bin/bash or /bin/sh:"
awk -F: '$7 ~ /\/(bash|sh)/ {print $1}' /etc/passwd | sort
echo
echo "Docker group members:"
getent group docker 2>/dev/null || echo "Docker group does not exist"
echo

# ---------- 3. DOCKER ENVIRONMENT ----------
echo "--- 3. DOCKER ENVIRONMENT ---"
if command -v docker >/dev/null 2>&1; then
    docker --version
    docker info 2>/dev/null | grep -E "Server Version|Storage Driver|Logging Driver|Cgroup Driver|Runtimes|Default Runtime|Kernel Version|Operating System|CPUs|Total Memory|Docker Root Dir" || true
    echo
    echo "Running containers:"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null || echo "Cannot list containers"
    echo
    echo "All containers (including stopped):"
    docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null || echo "Cannot list containers"
    echo
    echo "Docker volumes:"
    docker volume ls 2>/dev/null || echo "Cannot list volumes"
    echo
    echo "Docker networks:"
    docker network ls 2>/dev/null || echo "Cannot list networks"
else
    echo "Docker not found."
fi
echo

# ---------- 4. TUTOR INSTALLATION ----------
echo "--- 4. TUTOR INSTALLATION ---"
if command -v tutor >/dev/null 2>&1; then
    tutor --version
    # Try to detect TUTOR_ROOT from environment or default
    if [ -n "${TUTOR_ROOT:-}" ]; then
        TUTOR_ROOT="$TUTOR_ROOT"
    elif [ -d "$TUTOR_DEFAULT_ROOT" ]; then
        TUTOR_ROOT="$TUTOR_DEFAULT_ROOT"
    else
        TUTOR_ROOT="(not found)"
    fi
    echo "TUTOR_ROOT: $TUTOR_ROOT"
    echo
    echo "Tutor plugins:"
    tutor plugins list 2>/dev/null | mask_sensitive || echo "Cannot list plugins"
    echo
    echo "Key configuration values (masked):"
    for key in LMS_HOST CMS_HOST ENABLE_HTTPS CONTACT_EMAIL OPENEDX_RELEASE EDX_PLATFORM_VERSION; do
        val=$(tutor config printvalue "$key" 2>/dev/null || echo "not set")
        echo "  $key = $(echo "$val" | mask_sensitive)"
    done
    echo
    echo "Full config.yml (masked) – if present:"
    if [ -f "${TUTOR_ROOT}/config.yml" ]; then
        cat "${TUTOR_ROOT}/config.yml" | mask_sensitive
    else
        echo "  config.yml not found at $TUTOR_ROOT"
    fi
    echo
    echo "Custom mounts (from config.yml or env):"
    grep -i "MOUNTS:" -A 5 "${TUTOR_ROOT}/config.yml" 2>/dev/null || echo "No mounts defined"
    echo
    echo "Environment directory structure (top level):"
    if [ -d "${TUTOR_ROOT}/env" ]; then
        ls -la "${TUTOR_ROOT}/env" 2>/dev/null | head -20
    else
        echo "  env/ not found."
    fi
    echo
    echo "Ownership of Tutor root directory:"
    ls -ld "${TUTOR_ROOT}" 2>/dev/null || echo "Directory not found"
    echo "Ownership of env/ and data/ subdirectories:"
    ls -ld "${TUTOR_ROOT}/env" "${TUTOR_ROOT}/data" 2>/dev/null || echo "Some subdirectories missing"
else
    echo "tutor command not found."
fi
echo

# ---------- 5. RUNNING PROCESSES RELATED TO TUTOR ----------
echo "--- 5. RUNNING PROCESSES RELATED TO TUTOR ---"
ps aux | grep -E "[t]utor|[o]pen[e]dx|[u]wsgi|[c]elery" | head -20 || echo "No relevant processes found"
echo

# ---------- 6. SYSTEMD SERVICES ----------
echo "--- 6. SYSTEMD SERVICES ---"
systemctl list-unit-files --type=service | grep -E "tutor|openedx|caddy" || echo "No Tutor-related service files found"
echo
echo "Status of any tutor.service (if exists):"
systemctl status tutor.service 2>/dev/null || echo "tutor.service not found or not loaded"
echo

# ---------- 7. CRON JOBS ----------
echo "--- 7. CRON JOBS (root and tutor related) ---"
crontab -l 2>/dev/null | grep -i tutor || echo "No root crontab entries for tutor"
echo
echo "System crontabs (/etc/cron*):"
grep -r "tutor" /etc/cron* 2>/dev/null | head -10 || echo "No tutor entries found"
echo

# ---------- 8. FILE PERMISSIONS OF CRITICAL PATHS ----------
echo "--- 8. FILE PERMISSIONS (critical paths) ---"
for path in /root/.local/share/tutor-main /home/tutor/.local/share/tutor-main /etc/letsencrypt /var/lib/docker; do
    if [ -e "$path" ]; then
        echo "$path: $(ls -ld "$path" 2>/dev/null)"
    else
        echo "$path: not found"
    fi
done
echo

# ---------- 9. CURRENT ENVIRONMENT VARIABLES ----------
echo "--- 9. CURRENT ENVIRONMENT (Tutor relevant) ---"
env | grep -E "TUTOR|HOME|USER|PATH" | sort || echo "No relevant env vars"
echo

# ---------- 10. ADDITIONAL CUSTOMIZATIONS ----------
echo "--- 10. CUSTOM THEMES / MFE REPOSITORIES ---"
if [ -n "${TUTOR_ROOT:-}" ] && [ -d "${TUTOR_ROOT}/env/build/openedx/themes" ]; then
    ls -la "${TUTOR_ROOT}/env/build/openedx/themes" 2>/dev/null || echo "No themes directory"
else
    echo "Themes directory not found."
fi
echo
# Check for MFE custom repo settings
grep -i "MFE_" "${TUTOR_ROOT}/config.yml" 2>/dev/null | mask_sensitive || echo "No MFE customizations found"
echo

# ---------- 11. BACKUP FILES ----------
echo "--- 11. RECENT BACKUP FILES (last 7 days) ---"
find /root -name "*.sql" -o -name "*.tar.gz" -mtime -7 2>/dev/null | head -10 || echo "No recent backups found"
echo

# ---------- 12. CHECK FOR POSSIBLE CONFLICTS ----------
echo "--- 12. CONFLICT CHECKS (ports, other services) ---"
ss -tulpn | grep LISTEN | grep -E ":80|:443|:8000|:3306|:27017|:6379" || echo "No critical ports listening"
echo

echo "================================================================================"
echo "  INFORMATION GATHERING COMPLETE – saved to $REPORT_FILE"
echo "================================================================================"