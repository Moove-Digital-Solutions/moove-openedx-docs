# README-deployment.md – Open edX (Tutor) Production Deployment

**Version:** 1.0  
**Last updated:** 10 July 2026  
**Target environment:** Ubuntu 22.04 LTS, Tutor 21.0.8 (Indigo), Docker 29+  

---

## Table of Contents

1. [Overview](#overview)  
2. [System Requirements](#system-requirements)  
3. [Installation & Initial Setup](#installation--initial-setup)  
4. [Security Hardening: Non‑Root User Migration](#security-hardening-nonroot-user-migration)  
5. [Service Management](#service-management)  
6. [Development & Customization](#development--customization)  
7. [Upgrades](#upgrades)  
8. [Backup & Recovery](#backup--recovery)  
9. [Monitoring & Troubleshooting](#monitoring--troubleshooting)  
10. [References](#references)

---

## 1. Overview

This document describes the deployment of the **Moove Education Virtual** platform, a production instance of Open edX running under **Tutor**, with a dedicated non‑root user and systemd service.  
The stack includes:

- Open edX (LMS & CMS) – Indigo release (v21.0.8)
- Custom MFE `frontend-app-authn` (mounted from `/opt/tutor-mfe`)
- Indigo theme
- Forum plugin
- Meilisearch, MySQL, MongoDB, Redis, Caddy (HTTPS), SMTP relay

All components are containerised and orchestrated via Docker Compose, managed by Tutor.

---

## 2. System Requirements

| Component | Requirement |
|-----------|-------------|
| **OS** | Ubuntu 22.04 LTS (or later) |
| **CPU** | 4 cores (recommended) |
| **RAM** | 8 GB or more |
| **Storage** | 80 GB SSD (adjust for media growth) |
| **Docker** | 29+ (with Docker Compose plugin) |
| **Python** | 3.10 (system) |
| **Network** | Open ports 80, 443 (HTTPS), 22 (SSH) |
| **Domain** | `educationvirtual.net` (LMS) and `studio.educationvirtual.net` (CMS) |

---

## 3. Installation & Initial Setup

> **Note:** This guide assumes a fresh Ubuntu 22.04 server. For an existing system that already runs Tutor as `root`, follow the [Security Hardening](#security-hardening-nonroot-user-migration) section instead.

### 3.1. System Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install essential tools
sudo apt install -y git curl wget software-properties-common

# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Log out and back in for group change to take effect

# Install Docker Compose plugin
sudo apt install docker-compose-plugin -y
```

### 3.2. Install Tutor

We use a dedicated non‑root user `tutor` from the start (recommended).  
If you already have a root‑based Tutor installation, skip to section 4.

```bash
# Create tutor user
sudo useradd -m -s /bin/bash -U tutor
sudo passwd -l tutor
sudo usermod -aG docker tutor

# Switch to tutor user (or use sudo -u tutor for commands)
sudo -i -u tutor
```

### 3.3. Install Tutor in a Virtual Environment

```bash
# Create virtual environment
python3 -m venv ~/venv
source ~/venv/bin/activate
pip install --upgrade pip setuptools wheel

# Clone Tutor source (optional) or install from PyPI
pip install tutor==21.0.8

# Install plugins
pip install tutor-forum tutor-indigo tutor-mfe

# Initialise Tutor environment
export TUTOR_ROOT=/opt/tutor-data
tutor config save
```

### 3.4. Configure Domain and HTTPS

```bash
# Set domain names
tutor config set LMS_HOST educationvirtual.net
tutor config set CMS_HOST studio.educationvirtual.net
tutor config set ENABLE_HTTPS true
tutor config set CONTACT_EMAIL digmoove@gmail.com

# Save configuration
tutor config save
```

### 3.5. Launch the Platform

```bash
tutor local start
```

Verify with `curl -I https://educationvirtual.net`.

---

## 4. Security Hardening: Non‑Root User Migration

If Tutor was previously running as `root`, follow these steps to migrate to a dedicated `tutor` user.

### 4.1. Stop Tutor (as root)

```bash
sudo tutor local stop
```

### 4.2. Create `tutor` User

```bash
sudo useradd -m -s /bin/bash -U tutor
sudo passwd -l tutor
sudo usermod -aG docker tutor
```

### 4.3. Move Data to `/opt`

```bash
# Move Tutor main directory
sudo mv /root/.local/share/tutor-main /opt/tutor-data
sudo chown -R tutor:tutor /opt/tutor-data

# Move custom MFE (if any)
sudo mv /root/frontend-app-authn /opt/tutor-mfe
sudo chown -R tutor:tutor /opt/tutor-mfe

# Update config.yml with new mount path
sudo -u tutor sed -i 's|/root/frontend-app-authn|/opt/tutor-mfe|g' /opt/tutor-data/config.yml
```

### 4.4. Set Up Virtual Environment for Tutor

```bash
# Move Tutor source (if installed from source)
sudo mv /root/tutor /home/tutor/tutor
sudo chown -R tutor:tutor /home/tutor/tutor

# Create venv as tutor user
sudo -u tutor python3 -m venv /opt/tutor-venv
sudo -u tutor /opt/tutor-venv/bin/pip install --upgrade pip setuptools wheel
sudo -u tutor /opt/tutor-venv/bin/pip install /home/tutor/tutor
sudo -u tutor /opt/tutor-venv/bin/pip install tutor-forum tutor-indigo tutor-mfe
```

### 4.5. Regenerate Environment

```bash
sudo -u tutor env TUTOR_ROOT=/opt/tutor-data /opt/tutor-venv/bin/tutor config save
```

### 4.6. Create Systemd Service

Create `/etc/systemd/system/tutor.service`:

```ini
[Unit]
Description=Tutor Open edX Platform
After=docker.service network-online.target
Requires=docker.service
Wants=network-online.target

[Service]
Type=simple
User=tutor
Group=tutor

Environment="HOME=/home/tutor"
Environment="TUTOR_ROOT=/opt/tutor-data"
Environment="PATH=/opt/tutor-venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="PYTHONPATH=/opt/tutor-venv/lib/python3.10/site-packages"
Environment="DOCKER_CLI_PLUGIN_PATH=/usr/lib/docker/cli-plugins"

ExecStart=/opt/tutor-venv/bin/tutor local start
ExecStop=/opt/tutor-venv/bin/tutor local stop
ExecReload=/opt/tutor-venv/bin/tutor local restart

Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Reload and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable tutor.service
sudo systemctl start tutor.service
```

### 4.7. Verify and Clean Up

```bash
sudo systemctl status tutor.service
sudo -u tutor docker ps
curl -I https://educationvirtual.net
curl -I https://studio.educationvirtual.net

# Remove old root directories
sudo rm -rf /root/.local/share/tutor-main
sudo rm -rf /root/frontend-app-authn
```

---

## 5. Service Management

### 5.1. Systemd Commands (Preferred)

```bash
# Start the service
sudo systemctl start tutor.service

# Stop the service
sudo systemctl stop tutor.service

# Restart the service
sudo systemctl restart tutor.service

# View logs
sudo journalctl -u tutor.service -f

# Check status
sudo systemctl status tutor.service
```

### 5.2. Manual Tutor Commands (for maintenance)

All Tutor commands must be run as the `tutor` user with the appropriate environment:

```bash
sudo -u tutor env TUTOR_ROOT=/opt/tutor-data /opt/tutor-venv/bin/tutor <subcommand>
```

**Common commands:**

- `tutor local start` – Start all containers
- `tutor local stop`  – Stop all containers
- `tutor local restart` – Restart all
- `tutor local status` – Show container status
- `tutor local logs <service>` – View logs of a specific service (e.g., `lms`, `cms`, `mysql`)
- `tutor config save` – Regenerate configuration and compose files

---

## 6. Development & Customization

### 6.1. Custom MFEs

The custom authentication MFE (`frontend-app-authn`) is mounted from `/opt/tutor-mfe`.  
To make changes:

1. Modify the code in `/opt/tutor-mfe`.
2. Rebuild the MFE image:
   ```bash
   sudo -u tutor env TUTOR_ROOT=/opt/tutor-data /opt/tutor-venv/bin/tutor images build mfe
   ```
3. Restart the MFE container:
   ```bash
   sudo systemctl restart tutor.service
   ```
   Or, if you want faster iteration, you can mount the source in development mode (see Tutor documentation).

### 6.2. Custom Themes

The Indigo theme resides under `/opt/tutor-data/env/build/openedx/themes/indigo`.  
To customise:

1. Edit the theme files directly in that directory.
2. Recompile assets:
   ```bash
   sudo -u tutor env TUTOR_ROOT=/opt/tutor-data /opt/tutor-venv/bin/tutor local run lms python manage.py lms collectstatic
   sudo -u tutor env TUTOR_ROOT=/opt/tutor-data /opt/tutor-venv/bin/tutor local run cms python manage.py cms collectstatic
   ```
3. Restart services.

### 6.3. Plugin Management

List installed plugins:

```bash
sudo -u tutor env TUTOR_ROOT=/opt/tutor-data /opt/tutor-venv/bin/tutor plugins list
```

To install a new plugin, e.g., `tutor-android`:

```bash
sudo -u tutor /opt/tutor-venv/bin/pip install tutor-android
sudo -u tutor env TUTOR_ROOT=/opt/tutor-data /opt/tutor-venv/bin/tutor plugins enable android
sudo -u tutor env TUTOR_ROOT=/opt/tutor-data /opt/tutor-venv/bin/tutor config save
sudo systemctl restart tutor.service
```

---

## 7. Upgrades

### 7.1. Upgrading Tutor and Open edX

> **Warning:** Always test upgrades in a staging environment first. Back up your database and media before upgrading.

**1. Stop the service**

```bash
sudo systemctl stop tutor.service
```

**2. Backup the environment and database** (see [Backup & Recovery](#backup--recovery)).

**3. Upgrade the Tutor binary**

```bash
sudo -u tutor /opt/tutor-venv/bin/pip install --upgrade tutor==<new-version>
```

**4. Update plugins** (check compatibility)

```bash
sudo -u tutor /opt/tutor-venv/bin/pip install --upgrade tutor-forum tutor-indigo tutor-mfe
```

**5. Regenerate the environment**

```bash
sudo -u tutor env TUTOR_ROOT=/opt/tutor-data /opt/tutor-venv/bin/tutor config save
```

**6. Apply database migrations**

```bash
sudo -u tutor env TUTOR_ROOT=/opt/tutor-data /opt/tutor-venv/bin/tutor local run lms python manage.py lms migrate
sudo -u tutor env TUTOR_ROOT=/opt/tutor-data /opt/tutor-venv/bin/tutor local run cms python manage.py cms migrate
```

**7. Restart the service**

```bash
sudo systemctl start tutor.service
```

### 7.2. Rolling Back

If an upgrade fails, you can revert:

- Restore the database from backup.
- Reinstall the previous Tutor version in the venv:
  ```bash
  sudo -u tutor /opt/tutor-venv/bin/pip install tutor==<old-version>
  ```
- Restore the environment directory from backup (if you backed up `/opt/tutor-data/env`).
- Restart the service.

---

## 8. Backup & Recovery

### 8.1. What to Backup

- **Database (MySQL & MongoDB)** – critical
- **Media files** – `/opt/tutor-data/data/openedx-media`
- **Configuration** – `/opt/tutor-data/config.yml` and the entire `/opt/tutor-data/env` directory
- **Custom MFE and theme code** – `/opt/tutor-mfe` and theme directories

### 8.2. Automated Backup Script

Create a backup script (e.g., `/usr/local/bin/backup-tutor.sh`):

```bash
#!/bin/bash
BACKUP_DIR="/backup/tutor/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Stop the service (optional, but recommended for consistent DB dump)
sudo systemctl stop tutor.service

# MySQL dump
sudo -u tutor env TUTOR_ROOT=/opt/tutor-data /opt/tutor-venv/bin/tutor local exec mysql mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --all-databases > "$BACKUP_DIR/mysql.sql"

# MongoDB dump (using mongosh)
sudo -u tutor env TUTOR_ROOT=/opt/tutor-data /opt/tutor-venv/bin/tutor local exec mongodb mongodump --archive="$BACKUP_DIR/mongodb.archive" --gzip

# Media files
sudo tar -czf "$BACKUP_DIR/media.tar.gz" -C /opt/tutor-data/data/openedx-media .

# Environment and config
sudo tar -czf "$BACKUP_DIR/env.tar.gz" -C /opt/tutor-data env config.yml

# Custom MFE
sudo tar -czf "$BACKUP_DIR/mfe.tar.gz" -C /opt tutor-mfe

# Start the service again
sudo systemctl start tutor.service

# Keep only last 7 days
find /backup/tutor -type d -mtime +7 -exec rm -rf {} \;
```

Make it executable and schedule via cron (e.g., daily at 2 AM):

```bash
sudo crontab -e
# Add line:
0 2 * * * /usr/local/bin/backup-tutor.sh
```

### 8.3. Recovery

To restore from backup:

1. Stop the service: `sudo systemctl stop tutor.service`
2. Restore MySQL: `sudo -u tutor ... mysql -uroot -p"$MYSQL_ROOT_PASSWORD" < backup/mysql.sql`
3. Restore MongoDB: `sudo -u tutor ... mongorestore --archive=backup/mongodb.archive --gzip`
4. Restore media and environment from tar archives.
5. Restart the service.

---

## 9. Monitoring & Troubleshooting

### 9.1. Logging

- **Systemd logs:** `sudo journalctl -u tutor.service -f`
- **Container logs:**  
  ```bash
  sudo -u tutor env TUTOR_ROOT=/opt/tutor-data /opt/tutor-venv/bin/tutor local logs lms
  ```

### 9.2. Common Issues

| Symptom | Likely Cause | Solution |
|---------|--------------|----------|
| Service won’t start (exit code 203) | Docker Compose plugin not found | Check `DOCKER_CLI_PLUGIN_PATH` in service file. Ensure `docker compose` works as `tutor` user. |
| `No module named 'tutor'` | Virtual environment not activated in service | Ensure `PYTHONPATH` points to site‑packages. |
| Port 80/443 already in use | Another service (e.g., nginx) running | Stop the other service or change Tutor’s port mapping. |
| Caddy fails to obtain certificate | DNS or firewall issues | Check domain resolves to the server, and ports 80/443 are open. |

### 9.3. Performance Tuning

- Increase `UWSGI_WORKERS` in the Tutor config (e.g., set to number of CPU cores).
- Adjust `MEMORY_LIMIT` in Tutor config if memory is constrained.
- Monitor memory usage: `sudo systemctl status tutor.service` and `docker stats`.

---

## 10. References

- [Official Tutor Documentation](https://docs.tutor.overhang.io/)
- [Open edX Documentation](https://docs.openedx.org/)
- [Docker Compose Plugin](https://docs.docker.com/compose/install/linux/)
- [Systemd Service Unit Documentation](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
