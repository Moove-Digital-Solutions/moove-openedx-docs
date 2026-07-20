# Trivy Vulnerability Scanning for Open edX Production

This guide documents the setup, administration, and remediation process for Trivy vulnerability scanning on a production Open edX server running on Ubuntu 22.04 with Tutor‑managed Docker containers.

---

## Table of Contents
1. [Overview](#overview)
2. [Installation](#installation)
3. [Scan Script](#scan-script)
4. [Scheduling with Cron](#scheduling-with-cron)
5. [Log Rotation](#log-rotation)
6. [Manual Execution](#manual-execution)
7. [Understanding Reports](#understanding-reports)
8. [Vulnerability Remediation Guide](#vulnerability-remediation-guide)
9. [Maintenance and Updates](#maintenance-and-updates)
10. [Troubleshooting](#troubleshooting)

---

## Overview

Trivy is a comprehensive vulnerability scanner for container images and filesystems. The setup in this environment:
- Scans the **host filesystem** (`/`) for HIGH and CRITICAL vulnerabilities (ignoring unfixed).
- Scans all **local Docker images** (including Tutor‑built Open edX images) for HIGH/CRITICAL issues.
- Runs daily via cron; reports are stored in `/var/log/trivy/` with log rotation.
- Provides actionable insights for patching the host OS, base images, and application dependencies.

---

## Installation

Trivy is installed in `/usr/local/bin/trivy`. The installation script was run as:

```bash
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin
```

Verify the version:
```bash
trivy --version
# Version: 0.72.0
```

---

## Scan Script

The script is located at `/usr/local/bin/trivy_scan.sh`. It performs two scans:

1. **Filesystem scan** – skips heavy directories (`/var/lib/apt/lists`, `/var/lib/containerd`, `/var/lib/docker`, `/openedx/dist`, `/tmp`, `/var/tmp`) to avoid timeouts and memory exhaustion. Secret scanning is disabled (`--scanners vuln`) for speed.

2. **Docker image scan** – iterates over all local images, scanning each with a 15‑minute timeout.

### Script Content

```bash
#!/bin/bash
set -euo pipefail

DATE=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="/var/log/trivy"
mkdir -p "$REPORT_DIR"

echo "===== Trivy scan started at $(date) ====="

# ------------------------------------------------------------------
# 1. Host filesystem scan
# ------------------------------------------------------------------
FS_REPORT="$REPORT_DIR/trivy_fs_$DATE.txt"
echo "Scanning host filesystem (HIGH/CRITICAL, ignoring unfixed)..."

trivy fs / --severity HIGH,CRITICAL --ignore-unfixed --skip-dirs /var/lib/apt/lists,/var/lib/containerd,/var/lib/docker,/openedx/dist,/tmp,/var/tmp --scanners vuln --timeout 30m > "$FS_REPORT" 2>&1

if [ $? -eq 0 ]; then
    echo "Filesystem scan completed."
else
    echo "WARNING: Filesystem scan exited with code $? (check report)."
fi

# ------------------------------------------------------------------
# 2. Docker images scan
# ------------------------------------------------------------------
IMAGES_REPORT="$REPORT_DIR/trivy_images_$DATE.txt"
echo "Scanning Docker images..."

docker images --format "{{.Repository}}:{{.Tag}}" | grep -v '<none>' | while read -r img; do
    echo "===== Scanning $img =====" >> "$IMAGES_REPORT"
    trivy image --severity HIGH,CRITICAL --ignore-unfixed --timeout 15m "$img" >> "$IMAGES_REPORT" 2>&1
    echo "--------------------------------------------------" >> "$IMAGES_REPORT"
done

echo "===== Scan finished at $(date) ====="
echo "Reports saved in $REPORT_DIR"
```

**Make it executable:**
```bash
sudo chmod +x /usr/local/bin/trivy_scan.sh
```

---

## Scheduling with Cron

To run the scan **daily at 2:00 AM** (off‑peak hours):

```bash
sudo crontab -e
```

Add the following line:

```
0 2 * * * /usr/local/bin/trivy_scan.sh
```

Optionally, to receive email alerts on errors (if `mail` is configured):

```
MAILTO=admin@yourdomain.com
0 2 * * * /usr/local/bin/trivy_scan.sh
```

---

## Log Rotation

Reports can grow large; we keep **30 days** of compressed logs.

Create `/etc/logrotate.d/trivy`:

```bash
sudo tee /etc/logrotate.d/trivy > /dev/null <<'EOF'
/var/log/trivy/*.txt {
    daily
    rotate 30
    compress
    missingok
    notifempty
    create 0644 root root
}
EOF
```

---

## Manual Execution

Run the scan on demand:

```bash
sudo /usr/local/bin/trivy_scan.sh
```

After completion, list reports:

```bash
ls -lh /var/log/trivy/
```

---

## Understanding Reports

Each report is a plain‑text file with a table of vulnerabilities. The key sections:

- **Total**: `Total: X (HIGH: Y, CRITICAL: Z)` – summary per scan target.
- **Each vulnerability** shows:  
  `│ Package │ CVE ID │ Severity │ Status │ Installed Version │ Fixed Version │ Description │`

### Quick Analysis

- Count total findings:
  ```bash
  for f in /var/log/trivy/*.txt; do echo "$f: $(grep -c "HIGH\|CRITICAL" "$f") findings"; done
  ```

- Extract only HIGH/CRITICAL lines:
  ```bash
  grep -E "HIGH|CRITICAL" /var/log/trivy/trivy_*.txt | less
  ```

- Focus on **fixable** vulnerabilities (remove `--ignore-unfixed` temporarily or grep for `fixed`).

---

## Vulnerability Remediation Guide

Based on a recent scan (July 2026), the following **critical and high** vulnerabilities were identified. Recommended actions are prioritised.

### 🔴 Critical Vulnerabilities (Immediate Action)

| CVE | Component | Affected System | Fix |
|-----|-----------|----------------|-----|
| CVE‑2026‑33937 | Handlebars.js | Host filesystem | `npm update handlebars` to ≥4.7.9 |
| CVE‑2026‑9277 | shell‑quote | Host filesystem | `npm update shell-quote` to ≥1.8.4 |
| CVE‑2026‑54466 | websocket‑driver | Host filesystem | `npm update websocket-driver` to ≥0.7.5 |
| CVE‑2026‑33186 | gRPC‑Go | Multiple Docker images | Rebuild images with `google.golang.org/grpc` ≥1.79.3 |
| CVE‑2024‑24790 / CVE‑2025‑68121 | Go stdlib | Many images | Upgrade Go base to ≥1.21.11 or ≥1.24.13 |
| CVE‑2023‑24538 | Go html/template | Two images | Rebuild with Go ≥1.19.8 / 1.20.3 |
| CVE‑2026‑33845 / CVE‑2026‑31789 | GnuTLS / OpenSSL | Debian‑based images | Rebuild with updated Debian base (apt update) |
| CVE‑2025‑44005 | smallstep/certificates | Caddy image | Update to ≥0.29.0 |
| CVE‑2021‑23358 | underscore.js | Node images | `npm update underscore` to ≥1.12.1 |
| CVE‑2022‑2421 | socket.io‑parser | Node images | Update to ≥4.0.5 / 3.4.2 |
| CVE‑2025‑14009 | NLTK (Python) | Django image | Rebuild with `nltk` ≥3.9.3 |

### 🟠 High Vulnerabilities (Widespread)

- **Babel** (`CVE‑2026‑44728`) – many JS builds.
- **ws** (`CVE‑2026‑48779`) – Denial of Service.
- **OpenSSL** (`CVE‑2023‑5363`, `CVE‑2022‑3996`) – Alpine images.
- **BusyBox** (`CVE‑2021‑42378`) – Alpine.
- **Expat** (`CVE‑2025‑59375`) – Oracle Linux.
- **Django** (`CVE‑2026‑25673`) – Denial of Service.
- **Go packages** (`golang.org/x/crypto`, `opentelemetry`) – many outdated modules.

### Step‑by‑Step Remediation

#### 1. Update Host OS Packages
```bash
sudo apt update && sudo apt upgrade -y
# Reboot if kernel updated
sudo reboot
```

#### 2. Rebuild Open edX Docker Images
- Update base images in your Tutor configuration (e.g., `tutor images build`).
- Replace EOL Alpine versions (3.13–3.18) with **Alpine 3.20 or 3.21**.
- For Go‑based images, use `golang:1.24` or later.
- For Python images, upgrade `Django`, `cryptography`, and `nltk` in `requirements.txt`.

After updating, rebuild and redeploy:
```bash
tutor images build all
tutor local launch
```

#### 3. Fix Node.js Dependencies (Host)
Navigate to your Open edX frontend directories (e.g., `/openedx/edx-platform`) and run:
```bash
npm audit fix
# or manually update the packages listed
npm install handlebars@4.7.9 shell-quote@1.8.4 websocket-driver@0.7.5 ws@8.21.0
```

Rebuild the frontend assets:
```bash
tutor local run lms npm run build
```

#### 4. Update Go Modules in Custom Services
For any custom Go services, update `go.mod`:
```bash
go get google.golang.org/grpc@v1.79.3
go get golang.org/x/crypto@v0.52.0
go get go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp@v0.44.0
go mod tidy
```

Rebuild and redeploy those services.

#### 5. Verify with a New Scan
After applying fixes, run a manual scan and compare the totals. Ensure critical CVEs are resolved.

---

## Maintenance and Updates

### Trivy Updates
Check for new Trivy versions periodically:
```bash
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin
```

### Vulnerability Database Updates
Trivy automatically downloads the latest DB on each run. The DB is cached; to force a refresh:
```bash
trivy clean --db
```

### Report Retention
Log rotation keeps 30 days of reports. Adjust the `rotate` value in `/etc/logrotate.d/trivy` if needed.

### Monitoring
Consider integrating a monitoring script that alerts if the number of CRITICAL vulnerabilities exceeds a threshold. Example:
```bash
#!/bin/bash
CRIT=$(grep -c "CRITICAL" /var/log/trivy/trivy_images_$(date +%Y%m%d)*.txt)
if [ $CRIT -gt 10 ]; then
    echo "Alert: $CRIT critical vulnerabilities found" | mail -s "Trivy Alert" admin@example.com
fi
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| **Timeout during filesystem scan** | Increase `--timeout` or skip more directories via `--skip-dirs`. |
| **High memory usage** | Disable secret scanning (`--scanners vuln`) – already applied. |
| **“multiple targets cannot be specified”** | Ensure `trivy fs` command is on one line; no extra spaces. |
| **Database download fails** | Check network connectivity; set `--skip-db-update` and manually download if needed. |
| **Docker images not found** | Ensure Docker is running and images are present. |
| **Script fails due to `set -e`** | Consider wrapping each scan in `|| true` to continue on error, but that hides failures. |

### Debug Mode
Run a scan with `--debug` to see more details:
```bash
trivy fs / --severity HIGH,CRITICAL --ignore-unfixed --debug
```

---

## References

- [Trivy Documentation](https://trivy.dev/)
- [Open edX Tutor Documentation](https://docs.tutor.edly.io/)
- [Ubuntu Security Updates](https://ubuntu.com/security)
- [Alpine Linux Security Advisories](https://alpinelinux.org/advisories/)

---

*Last updated: July 2026*
