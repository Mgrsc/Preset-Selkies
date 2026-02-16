# Selkies Desktop Environment - LLM Context

## Project Overview

## What You Can Help With
- Add/remove pre-installed applications
- Configure auto-start behavior via environment variables
- Troubleshoot application launch failures
- Modify container configuration (docker-compose.yml)
- Debug startup scripts and process management

## What Not to Change
- Base image source: `ghcr.io/linuxserver/baseimage-selkies:ubuntunoble`
- Mount path: `/config` (persistence layer)
- GPU passthrough: `/dev/dri` (unless explicitly requested)
- shm_size: Currently set to 2GB, must stay ≥1GB (browser requirement)

---

## Architecture

### File Structure
```
├── Dockerfile              # App installation, locale setup, script deployment
├── docker-compose.yml      # Service definition, env vars, volume mounts
├── scripts/
│   ├── system-start.sh     # Openbox init, wallpaper, tray, menu sync
│   ├── autostart-apps.sh   # Env-driven app launcher
│   └── app-restart.sh      # Debounced single-instance launcher
├── assets/
│   ├── Background.png      # Default wallpaper
│   └── app-icon.png        # Tray icons
└── config/
    └── menu.xml            # Openbox menu template
```

### Startup Sequence
```
Container Start
    ↓
Openbox Autostart
    ↓
system-start.sh (dock/menu/wallpaper/tray setup)
    ↓
autostart-apps.sh (check AUTO_START_* env vars)
    ↓
app-restart.sh (launch apps with debounce + single-instance check)
```

### Key Mechanisms
- **Debounce**: 5-second lockfile (`/tmp/<app>-restart.lock`) prevents rapid restarts
- **Single Instance**: `pidof -x` check exits if process already running
- **Env-Driven Launch**: Apps start only if `AUTO_START_<APPNAME>=true`
- **Persistence**: All user data in `/config` (mounted to `./config` on host)

---

## Adding a New Application

### Standard Flow (for .deb packages)

#### 1. Dockerfile Modifications
Add at the top (after existing ARGs):
```dockerfile
ARG MYAPP_VERSION="myapp_1.0.0_amd64.deb"
ARG MYAPP_URL="https://example.com/${MYAPP_VERSION}"
```

In the main RUN block (after existing curl commands):
```dockerfile
curl -fsSL --retry 3 --retry-delay 2 -o /tmp/myapp.deb "${MYAPP_URL}" || \
    { echo "ERROR: Failed to download MyApp"; exit 1; } && \
[ -f /tmp/myapp.deb ] && [ -s /tmp/myapp.deb ] || \
    { echo "ERROR: MyApp download corrupted"; exit 1; } && \
```

Update dpkg install line to include new package:
```dockerfile
```

Add cleanup:
```dockerfile
```

Add ENV variable (in ENV block):
```dockerfile
ENV AUTO_START_MYAPP="false"
```

#### 2. Update autostart-apps.sh
Insert before the final log line:
```bash
if [ "${AUTO_START_MYAPP:-false}" = "true" ]; then
    if [ -x /usr/bin/myapp ]; then
        log "Starting MyApp..."
        bash /scripts/app-restart.sh /usr/bin/myapp >> "$LOG_FILE" 2>&1
    else
        log "Warning: MyApp not found or not executable"
    fi
fi
```

Add `--no-sandbox` if Chromium-based:
```bash
bash /scripts/app-restart.sh /usr/bin/myapp --no-sandbox >> "$LOG_FILE" 2>&1
```

#### 3. Update docker-compose.yml
Add to `environment:` section:
```yaml
- AUTO_START_MYAPP=false
```

#### 4. Build and Test
```bash
docker build -t ghcr.io/mgrsc/agent-selkies:test .
docker run --rm -it -p 3001:3000 --device /dev/dri \
    -e AUTO_START_MYAPP=true \
    ghcr.io/mgrsc/agent-selkies:test

# Check logs
docker exec <container> cat /config/.config/openbox/autostart.log
docker exec <container> ps aux | grep myapp
```

### Alternative Installation Methods

**APT packages**:
```dockerfile
RUN apt-get update && apt-get install -y \
    myapp \
    && rm -rf /var/lib/apt/lists/*
```

**Binary downloads**:
```dockerfile
RUN curl -fsSL -o /usr/local/bin/myapp https://example.com/myapp && \
    chmod +x /usr/local/bin/myapp
```

**AppImage** (requires FUSE):
```dockerfile
RUN apt-get install -y fuse libfuse2 && \
    curl -fsSL -o /opt/myapp.AppImage https://example.com/myapp.AppImage && \
    chmod +x /opt/myapp.AppImage
```

---

## Troubleshooting Guide

### Application Won't Start

**Check installation**:
```bash
docker exec <container> which myapp
docker exec <container> dpkg -l | grep myapp
```

**Check binary permissions**:
```bash
docker exec <container> ls -la /usr/bin/myapp
```

**View logs**:
```bash
docker exec <container> tail -f /config/.config/openbox/autostart.log
```

**Test manual launch**:
```bash
docker exec <container> /usr/bin/myapp
```

**Check dependencies**:
```bash
docker exec <container> ldd /usr/bin/myapp
```

### Common Issues

| Symptom | Likely Cause | Solution |
|---------|--------------|----------|
| App not in process list | Binary path wrong | Verify with `which <app>` |
| Immediate crash | Missing `--no-sandbox` | Add flag in autostart-apps.sh |
| "Permission denied" | Wrong PUID/PGID | Check docker-compose.yml env vars |
| Blank screen | shm_size too small | Increase to ≥1GB |
| Chinese input broken | fcitx not running | Check base image fcitx setup |

### Log Analysis
Primary log: `/config/.config/openbox/autostart.log`

Key patterns:
- `Starting <App>...` → Launch attempted
- `Warning: <App> not found` → Binary path issue
- `ERROR: Failed to download` → Build-time download failure
- No output → Check if autostart-apps.sh executed

---

## Configuration Reference

### Environment Variables (docker-compose.yml)

**Auto-start controls**:
```yaml
AUTO_START_WECHAT=false    # Launch WeChat on boot
                           # Note: Dockerfile default is "true", but docker-compose.yml
                           # overrides it to "false" for user control
AUTO_START_QQ=false        # Launch QQ on boot
```

**Permissions**:
```yaml
PUID=1000                  # User ID for /config ownership
PGID=1000                  # Group ID for /config ownership
```

**Authentication** (optional):
```yaml
CUSTOM_USER=myuser         # Web interface username
PASSWORD=mypassword        # Web interface password
```

**Selkies tuning** (commented by default):
```yaml
SELKIES_ENCODER=nvh264enc  # GPU encoder (nvh264enc/x264enc)
SELKIES_FRAMERATE=60       # Target FPS
DISPLAY_SIZEW=1920         # Resolution width
DISPLAY_SIZEH=1080         # Resolution height
```

### Naming Conventions
- ENV variables: `AUTO_START_<APPNAME>` (uppercase, underscores)
- Lock files: `/tmp/<appname>-restart.lock`
- Log file: `/config/.config/openbox/autostart.log` (fixed path)

---

## Technical Details

### Locale & Timezone
- `LC_ALL=zh_CN.UTF-8`
- `TZ=Asia/Shanghai`
- Fonts: `fonts-noto-cjk` (Chinese/Japanese/Korean)

### Clipboard
- Enabled via `SELKIES_CLIPBOARD_ENABLED=true`
- Binary clipboard: `SELKIES_ENABLE_BINARY_CLIPBOARD=true`

### Process Management
- **app-restart.sh** uses lockfile mechanism (5s timeout)
- Single instance enforced via `pidof -x <app-name>`
- Apps launched with `nohup` for background execution

### Persistence Layer
- Mount point: `/config` → `./config` (host)
- Contains: user data, app configs, downloads, logs
- Ownership controlled by PUID/PGID

---

## Quick Reference Commands

**View running apps**:
```bash
```

**Restart specific app**:
```bash
docker exec agent-selkies pkill wechat
docker exec agent-selkies bash /scripts/app-restart.sh /usr/bin/wechat
```

**Check container logs**:
```bash
docker logs agent-selkies
```

**Access shell**:
```bash
docker exec -it agent-selkies bash
```

**Rebuild image**:
```bash
docker-compose build --no-cache
docker-compose up -d
```

---

## Response Guidelines for LLMs

### When Adding Apps
1. Provide complete Dockerfile snippet (ARG + download + install + ENV)
2. Show autostart-apps.sh modification with correct binary path
3. Include docker-compose.yml env var addition
4. Give build/test commands

### When Troubleshooting
1. Ask for specific error symptoms
2. Provide diagnostic commands (not explanations first)
3. Prioritize log checking over speculation
4. Suggest fixes in order of likelihood

### Code Style
- Use minimal, working examples
- Include inline comments for non-obvious parts
- Mark omitted sections with `# ...existing code...`
- Specify file names clearly when modifying multiple files

### Constraints
- Don't suggest modifying base image internals
- Don't change `/config` mount path
- Don't remove GPU passthrough without user request
- Don't reduce shm_size below 1GB
