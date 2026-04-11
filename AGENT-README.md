# AGENT-README

Canonical agent entry point for this repository.

## Repository Purpose

Preset-Selkies builds a browser-accessible Linux desktop image on top of `ghcr.io/linuxserver/baseimage-selkies:ubuntunoble`. The image adds WeChat, QQ, Thorium, Chinese locale defaults, clipboard sync, and a QQ watchdog for X11 client growth.

## File Responsibility Map

- [`Dockerfile`](./Dockerfile): base image, package installation, downloaded app artifacts, environment defaults, shipped assets, and startup script deployment
- [`docker-compose.yml`](./docker-compose.yml): runtime service definition, environment variables, port mapping, `/config` persistence, `/dev/dri` passthrough, `shm_size`
- [`scripts/system-start.sh`](./scripts/system-start.sh): Openbox setup, wallpaper application, tray startup, clipboard sync startup, autostart trigger
- [`scripts/autostart-apps.sh`](./scripts/autostart-apps.sh): environment-driven app launch orchestration
- [`scripts/app-restart.sh`](./scripts/app-restart.sh): single-instance launch helper with a 5-second lockfile debounce
- [`scripts/qq-watchdog.sh`](./scripts/qq-watchdog.sh): QQ recovery loop based on X11 socket pressure
- [`scripts/clipboard-sync.sh`](./scripts/clipboard-sync.sh): text clipboard synchronization
- [`scripts/x11-diagnose.sh`](./scripts/x11-diagnose.sh): X11 client diagnostics
- [`config/menu.xml`](./config/menu.xml): default Openbox menu copied into `/config`
- [`config/alacritty.toml`](./config/alacritty.toml): default Alacritty configuration copied into `/config`
- [`README.md`](./README.md) and [`README.zh-CN.md`](./README.zh-CN.md): human-facing documentation that must stay aligned with runtime behavior

## Runtime Model

### Startup Sequence

```text
Openbox autostart
  -> /scripts/system-start.sh
  -> /scripts/autostart-apps.sh
  -> /scripts/app-restart.sh
```

### Persistent State

- Host `./config` is mounted to container `/config`
- Startup logs are written to `/config/.config/openbox/autostart.log`
- Openbox and Alacritty defaults are copied from `/defaults` into `/config` at startup if missing or outdated

## Public Interfaces

### Environment Variables

Auto-start:

- `AUTO_START_WECHAT`
- `AUTO_START_QQ`
- `AUTO_START_THORIUM`

QQ watchdog:

- `QQ_FLAGS`
- `QQ_WATCHDOG_ENABLED`
- `QQ_WATCHDOG_INTERVAL_SEC`
- `QQ_WATCHDOG_THRESHOLD`
- `QQ_WATCHDOG_RECOVERY_TARGET`
- `QQ_WATCHDOG_RESTART_COOLDOWN_SEC`

Container runtime:

- `PUID`
- `PGID`
- `CUSTOM_USER`
- `PASSWORD`
- `MAX_RESOLUTION`

### Operational Commands

View startup log:

```bash
docker exec preset-selkies tail -f /config/.config/openbox/autostart.log
```

Restart an app:

```bash
docker exec preset-selkies bash /scripts/app-restart.sh /usr/bin/wechat
docker exec preset-selkies bash /scripts/app-restart.sh /usr/bin/qq --no-sandbox
docker exec preset-selkies bash /scripts/app-restart.sh /usr/bin/thorium-browser --no-sandbox --test-type --disable-infobars
```

Inspect QQ X11 pressure:

```bash
docker exec preset-selkies bash /scripts/x11-diagnose.sh
docker exec preset-selkies bash /scripts/x11-diagnose.sh --watch 2 30
```

## Guardrails

- Keep the base image as `ghcr.io/linuxserver/baseimage-selkies:ubuntunoble` unless the user explicitly requests a base change
- Keep `/config` as the persistence mount point
- Do not remove `/dev/dri` passthrough or reduce `shm_size` below `1gb` unless explicitly requested
- Remember that [`docker-compose.yml`](./docker-compose.yml) consumes a published `image:` and does not declare `build:`; local image testing requires an explicit `docker build` and an updated image tag
- If behavior changes, update `README.md`, `README.zh-CN.md`, and this file in the same task
- Prefer minimal, targeted changes to the startup scripts because they are tightly coupled through log paths, default locations, and process names

## Common Failure Modes

- App fails to auto-start:
  Check the relevant `AUTO_START_*` variable, confirm the binary path exists, then inspect `autostart.log`
- QQ causes stream instability over time:
  Inspect `QQ_WATCHDOG_*`, review `qq-watchdog.sh`, and use `x11-diagnose.sh`
- Blank stream or browser instability:
  Confirm `shm_size` remains at or above `1gb`
- Clipboard sync appears broken:
  Confirm `clipnotify`, `xclip`, and `clipboard-sync.sh` are present and running inside the container

## Change Workflow for New Apps

1. Update [`Dockerfile`](./Dockerfile) with install steps and image-level defaults.
2. Update [`scripts/autostart-apps.sh`](./scripts/autostart-apps.sh) with launch logic.
3. Update [`docker-compose.yml`](./docker-compose.yml) with the user-facing environment variable.
4. Update [`README.md`](./README.md), [`README.zh-CN.md`](./README.zh-CN.md), and this file if the change affects usage or operations.
5. For Chromium or Electron apps, evaluate whether `--no-sandbox` or X11 monitoring is required.

## Verification Notes

This repository currently has no committed automated tests. Validation is usually done by checking configuration, starting the container, and inspecting startup logs. Do not run the container unless the user explicitly requests execution or supplies verification expectations.
