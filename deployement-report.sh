#!/bin/bash
# ============================================================================
# Open edX (Tutor) Deployment Deep-Dive Report – fixed masking
# ============================================================================

set -euo pipefail

REPORT_DIR="/root"
REPORT_FILE="${REPORT_DIR}/deployment-report-$(date +%Y%m%d-%H%M%S).txt"
TUTOR_ENV_DIR="/root/.local/share/tutor-main"

# ----- Safe masking function (Perl preferred, fallback to sed) -----
mask_sensitive() {
    if command -v perl >/dev/null 2>&1; then
        perl -pe '
            s/(password|secret|key|token|PASS|SECRET|KEY|TOKEN)[:=]\s*\K[^\s,]+/***MASKED***/gi;
            s/(-----BEGIN RSA PRIVATE KEY-----).*?(-----END RSA PRIVATE KEY-----)/$1\n  ***MASKED***\n$2/gs;
        '
    else
        # Fallback: only mask simple assignments (avoids delimiter conflicts)
        sed -E 's/(password|secret|key|token|PASS|SECRET|KEY|TOKEN)[:=][[:space:]]*[^[:space:]]+/\1=***MASKED***/gi'
    fi
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

# Start fresh report
exec > >(tee -a "$REPORT_FILE") 2>&1

echo "================================================================================"
echo "  OPEN EDX (TUTOR) DEPLOYMENT – COMPREHENSIVE SYSTEM REPORT"
echo "  Generated: $(date)"
echo "================================================================================"
echo

# ---- 1. SYSTEM ----
echo "--- 1. SYSTEM OVERVIEW ---"
hostname -f
uname -a
lsb_release -d 2>/dev/null || echo "lsb_release not available"
uptime -p
uptime | awk -F'load average:' '{print "Load average:" $2}'
echo

# ---- 2. HARDWARE ----
echo "--- 2. HARDWARE & RESOURCES ---"
lscpu | grep -E "Model name|CPU\(s\)|Thread|Core|Socket|Cache" || true
free -h
df -h --total | grep -v tmpfs
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT 2>/dev/null || true
echo

# ---- 3. NETWORK ----
echo "--- 3. NETWORK ---"
ip -4 addr show | grep inet | awk '{print $2}' || true
ss -tulpn | grep LISTEN || true
if command_exists tutor; then
    lms_host=$(tutor config printvalue LMS_HOST 2>/dev/null || echo "unknown")
    cms_host=$(tutor config printvalue CMS_HOST 2>/dev/null || echo "unknown")
    echo "LMS_HOST: $lms_host -> $(dig +short $lms_host | head -1)"
    echo "CMS_HOST: $cms_host -> $(dig +short $cms_host | head -1)"
fi
echo

# ---- 4. PACKAGES ----
echo "--- 4. KEY INSTALLED PACKAGES ---"
for pkg in docker docker-compose git python3 python3-pip nodejs npm tutor; do
    if command_exists $pkg; then
        version=$($pkg --version 2>/dev/null | head -1 || echo "installed")
        echo "$pkg: $version"
    else
        echo "$pkg: not found"
    fi
done
echo

# ---- 5. DOCKER ----
echo "--- 5. DOCKER ENVIRONMENT ---"
if command_exists docker; then
    docker --version
    docker info | grep -E "Server Version|Storage Driver|Logging Driver|Cgroup Driver|Runtimes|Default Runtime|Kernel Version|Operating System|CPUs|Total Memory|Docker Root Dir" || true
    echo
    docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" || true
    echo
    docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" || true
    echo
    docker volume ls || true
    echo
    docker network ls || true
    echo
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" || true
    echo

    echo "--- 5a. CONTAINER INSPECT (running only) ---"
    for c in $(docker ps -q); do
        name=$(docker inspect -f '{{.Name}}' $c | cut -c2-)
        echo ">> Container: $name"
        docker inspect -f '{{.Config.Image}}' $c 2>/dev/null || true
        echo "  Command: $(docker inspect -f '{{.Path}} {{.Args}}' $c 2>/dev/null || true)"
        echo "  Mounts:"
        docker inspect -f '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}' $c 2>/dev/null | sed 's/^/    /' || true
        echo "  Ports:"
        docker port $c 2>/dev/null | sed 's/^/    /' || true
        echo "  Environment (masked):"
        docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' $c 2>/dev/null | mask_sensitive | sed 's/^/    /' || true
        echo "  Labels:"
        docker inspect -f '{{range $k,$v := .Config.Labels}}{{printf "%s=%s" $k $v}}{{println}}{{end}}' $c 2>/dev/null | sed 's/^/    /' || true
        echo "---"
    done
else
    echo "Docker not found."
fi
echo

# ---- 6. TUTOR ----
echo "--- 6. TUTOR SPECIFICS ---"
if command_exists tutor; then
    tutor --version
    echo "Tutor root: $TUTOR_ENV_DIR"
    echo
    tutor plugins list | mask_sensitive || true
    echo
    echo "Key configuration values (masked):"
    for key in LMS_HOST CMS_HOST ENABLE_HTTPS CONTACT_EMAIL OPENEDX_RELEASE EDX_PLATFORM_VERSION; do
        val=$(tutor config printvalue $key 2>/dev/null || echo "not set")
        echo "  $key = $(echo "$val" | mask_sensitive)"
    done
    echo
    echo "Tutor configuration file (masked):"
    if [ -f "${TUTOR_ENV_DIR}/config.yml" ]; then
        cat "${TUTOR_ENV_DIR}/config.yml" | mask_sensitive
    else
        echo "  config.yml not found."
    fi
    echo
    echo "Environment directory structure:"
    if [ -d "${TUTOR_ENV_DIR}/env" ]; then
        ls -laR "${TUTOR_ENV_DIR}/env" | head -100
    else
        echo "  env/ not found."
    fi
    echo
    echo "Local docker-compose overrides (if any):"
    if [ -f "${TUTOR_ENV_DIR}/env/local/docker-compose.override.yml" ]; then
        cat "${TUTOR_ENV_DIR}/env/local/docker-compose.override.yml" | mask_sensitive
    else
        echo "  No override file."
    fi
else
    echo "Tutor command not found."
fi
echo

# ---- 7. SERVICE HEALTH & LOGS ----
echo "--- 7. OPEN EDX SERVICE HEALTH ---"
if command_exists tutor; then
    tutor local status || echo "  Failed to get status"
    echo
    lms_host=$(tutor config printvalue LMS_HOST 2>/dev/null || echo "localhost")
    cms_host=$(tutor config printvalue CMS_HOST 2>/dev/null || echo "localhost")
    echo "Checking LMS (https://$lms_host):"
    curl -s -o /dev/null -w "  HTTP %{http_code} (%{time_total}s)\n" "https://$lms_host" || echo "  Unreachable"
    echo "Checking CMS (https://$cms_host):"
    curl -s -o /dev/null -w "  HTTP %{http_code} (%{time_total}s)\n" "https://$cms_host" || echo "  Unreachable"
    echo
    echo "Recent logs (last 10 lines per service):"
    for svc in lms cms lms-worker cms-worker mysql mongodb redis meilisearch caddy mfe; do
        echo ">>> $svc <<<"
        tutor local logs --tail=10 $svc 2>/dev/null | tail -10 || echo "  No logs or service not found."
        echo
    done
else
    echo "Tutor not available."
fi
echo

# ---- 8. DATABASES ----
echo "--- 8. DATABASES ---"
echo "--- 8a. MySQL ---"
if command_exists tutor; then
    mysql_root_pw=$(tutor config printvalue MYSQL_ROOT_PASSWORD 2>/dev/null || echo "")
    if [ -n "$mysql_root_pw" ]; then
        echo "Databases:"
        docker exec tutor_main_local-mysql-1 mysql -uroot -p"$mysql_root_pw" -e "SHOW DATABASES;" 2>/dev/null | mask_sensitive || echo "  MySQL query failed"
        echo
        echo "Tables in 'openedx' database (sample):"
        docker exec tutor_main_local-mysql-1 mysql -uroot -p"$mysql_root_pw" -e "USE openedx; SHOW TABLES;" 2>/dev/null | head -30 || echo "  Query failed"
        echo
        echo "Table count and size:"
        docker exec tutor_main_local-mysql-1 mysql -uroot -p"$mysql_root_pw" -e "SELECT table_schema, COUNT(*) tables, ROUND(SUM(data_length+index_length)/1024/1024,2) size_mb FROM information_schema.tables WHERE table_schema='openedx' GROUP BY table_schema;" 2>/dev/null || echo "  Query failed"
    else
        echo "Could not retrieve MySQL root password."
    fi
else
    echo "Tutor not available."
fi

echo "--- 8b. MongoDB ---"
if command_exists tutor; then
    echo "MongoDB databases:"
    docker exec tutor_main_local-mongodb-1 mongosh --quiet --eval "db.adminCommand('listDatabases')" 2>/dev/null | grep -v "MongoDB" || echo "  mongosh not available"
    echo
    echo "Collections in 'openedx' database:"
    docker exec tutor_main_local-mongodb-1 mongosh --quiet --eval "use openedx; db.getCollectionNames()" 2>/dev/null || echo "  Cannot access"
else
    echo "Tutor not available."
fi
echo

# ---- 9. SECURITY ----
echo "--- 9. SECURITY ---"
ufw status verbose 2>/dev/null | head -20 || echo "ufw not installed"
iptables -L -n -v 2>/dev/null | head -30 || echo "iptables not accessible"
if [ -d "/etc/letsencrypt/live" ]; then
    ls -l /etc/letsencrypt/live/
    for cert in /etc/letsencrypt/live/*/fullchain.pem; do
        if [ -f "$cert" ]; then
            echo "  $cert: $(openssl x509 -enddate -noout -in $cert | cut -d= -f2)"
        fi
    done
else
    echo "  No Let's Encrypt directory found."
fi
echo
echo "Sensitive environment variables in running processes (masked):"
ps aux | grep -E "(PASSWORD|SECRET|KEY|TOKEN)" | grep -v grep | mask_sensitive | head -20 || true
echo

# ---- 10. DEVELOPMENT ----
echo "--- 10. DEVELOPMENT ENVIRONMENT & CUSTOMIZATIONS ---"
echo "Check for source code mounts (edx-platform, MFE):"
docker inspect tutor_main_local-lms-1 2>/dev/null | jq '.[0].Mounts' 2>/dev/null || echo "  Could not inspect"
echo
echo "Git repositories in /openedx (if mounted):"
docker exec tutor_main_local-lms-1 ls -la /openedx/edx-platform 2>/dev/null || echo "  edx-platform not mounted"
echo
echo "Custom themes (if any):"
if [ -d "${TUTOR_ENV_DIR}/env/build/openedx/themes" ]; then
    ls -la "${TUTOR_ENV_DIR}/env/build/openedx/themes"
else
    echo "  No custom themes directory."
fi
echo
echo "Settings overrides (env/local/openedx/):"
if [ -d "${TUTOR_ENV_DIR}/env/local/openedx" ]; then
    find "${TUTOR_ENV_DIR}/env/local/openedx" -name "*.py" -exec echo {} \; -exec head -5 {} \; 2>/dev/null
else
    echo "  No local settings overrides."
fi
echo

# ---- 11. USERS & PROCESSES ----
echo "--- 11. USERS & PROCESSES ---"
who
last -n 10 2>/dev/null || echo "last command not available"
crontab -l 2>/dev/null || echo "  No crontab for root"
systemctl list-units --type=service --state=running 2>/dev/null | head -20 || echo "systemctl not available"
echo "Total processes: $(ps aux | wc -l)"
ps aux --sort=-%cpu | head -10
echo

# ---- 12. BACKUP & MONITORING ----
echo "--- 12. BACKUP & MONITORING ---"
echo "Check for backup scripts or cron jobs:"
grep -r "backup" /etc/cron* 2>/dev/null || echo "  No backup cron entries found."
echo
echo "Log rotation (logrotate):"
if [ -f "/etc/logrotate.conf" ]; then
    grep -r "openedx" /etc/logrotate.d/ 2>/dev/null || echo "  No Open edX logrotate config."
else
    echo "  logrotate not configured."
fi
echo
echo "Docker log drivers:"
docker inspect tutor_main_local-lms-1 2>/dev/null | jq '.[0].HostConfig.LogConfig' 2>/dev/null || echo "  Could not inspect"
echo

# ---- 13. ADDITIONAL CHECKS ----
echo "--- 13. ADDITIONAL CHECKS ---"
if command_exists tutor; then
    echo "Check for demo course:"
    tutor local run lms python manage.py lms show_migration_status 2>/dev/null | head -5
fi
echo
echo "Superuser existence:"
docker exec tutor_main_local-lms-1 python manage.py lms shell -c "from django.contrib.auth import get_user_model; User=get_user_model(); print(User.objects.filter(is_superuser=True).exists())" 2>/dev/null || echo "  Could not check"

echo "================================================================================"
echo "  REPORT COMPLETE – saved to $REPORT_FILE"
echo "================================================================================"