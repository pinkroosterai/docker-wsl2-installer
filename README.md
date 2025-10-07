# Docker Engine in WSL2 Setup

Complete automation for installing Docker Engine in WSL2 without Docker Desktop.

## Prerequisites

- Windows 10 build 19043+ or Windows 11
- Administrator access

## Installation Steps

### Step 1: Run PowerShell Script (Windows)

1. Open PowerShell as Administrator
2. Run the setup script:

```powershell
.\setup-wsl2-docker.ps1
```

This will:
- Install/update WSL2
- Install Ubuntu 24.04
- Configure WSL2 as default

### Step 2: Run Bash Script (Ubuntu/WSL2)

1. Open Ubuntu (from Start Menu or run `wsl`)
2. Navigate to where you saved the script
3. Make it executable and run:

```bash
chmod +x install-docker-wsl2.sh
./install-docker-wsl2.sh
```

### Step 3: Restart WSL

From PowerShell (Windows):

```powershell
wsl --shutdown
```

Then open Ubuntu again.

### Step 4: Verify Installation

In Ubuntu, run:

```bash
~/verify-docker.sh
```

## What Gets Installed

- Docker Engine (latest stable)
- Docker Compose Plugin
- Docker Buildx Plugin
- Containerd
- Systemd configuration for auto-start

## Post-Installation

Docker will now start automatically whenever you open WSL!

Test with:
```bash
docker run hello-world
docker compose version
```

## Troubleshooting

**Docker daemon not running:**
```bash
sudo systemctl start docker
sudo systemctl status docker
```

**Permission denied:**
```bash
# Log out and back in, or run:
newgrp docker
```

**Systemd not working:**
```bash
# Check wsl.conf
cat /etc/wsl.conf

# Ensure you ran: wsl --shutdown
```
