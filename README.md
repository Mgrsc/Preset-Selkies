# Preset-Selkies Desktop

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Docker Image](https://img.shields.io/badge/Docker-ghcr.io-blue?logo=docker)](https://github.com/Mgrsc/Preset-Selkies/pkgs/container/preset-selkies)
[![Build Status](https://github.com/Mgrsc/Preset-Selkies/actions/workflows/build-docker.yml/badge.svg)](https://github.com/Mgrsc/Preset-Selkies/actions/workflows/build-docker.yml)

> Containerized Linux desktop based on LinuxServer Selkies, preloaded with WeChat, QQ, and Thorium for browser-based remote desktop use with Chinese locale defaults.

Chinese documentation: [README.zh-CN.md](./README.zh-CN.md)

## Table of Contents
- [Features](#features)
- [Quickstart](#quickstart)
- [Configuration](#configuration)
- [Architecture](#architecture)
- [Troubleshooting](#troubleshooting)
- [For AI Agents](#for-ai-agents)
- [License](#license)

## Features

- Browser-accessible Linux desktop over HTTPS on port `3000`
- Preinstalled `wechat`, `qq`, and `thorium-browser`
- Environment-variable controlled app auto-start
- Chinese locale defaults with bundled CJK fonts
- Persistent user data mounted through `/config`
- Clipboard sync between X selections via `clipnotify` and `xclip`
- QQ X11 connection watchdog to recover from `Maximum number of clients reached`

## Quickstart

### Prerequisites

- Docker Engine with the Compose plugin
- A host that exposes `/dev/dri` if you keep the default hardware acceleration mapping
- A modern browser that can open `https://localhost:3000`

### Run the published image

```bash
git clone https://github.com/Mgrsc/Preset-Selkies.git
cd Preset-Selkies
docker compose up -d
```

Open `https://localhost:3000`.

If `PASSWORD` is set in [`docker-compose.yml`](./docker-compose.yml), sign in with `CUSTOM_USER` and `PASSWORD`. If `PASSWORD` is empty, the web desktop is exposed without an application-level login prompt.

### Build locally after changing the image

```bash
docker build -t preset-selkies:local .
```

Then update `image:` in [`docker-compose.yml`](./docker-compose.yml) to `preset-selkies:local` before starting the container.

## Configuration

The main runtime settings live in [`docker-compose.yml`](./docker-compose.yml).

### Auto-start controls

| Variable | Default in image | Default in compose file | Purpose |
| --- | --- | --- | --- |
| `AUTO_START_WECHAT` | `true` | `false` | Launch WeChat during desktop startup |
| `AUTO_START_QQ` | `false` | `false` | Launch QQ during desktop startup |
| `AUTO_START_THORIUM` | `false` | `false` | Launch Thorium during desktop startup |

### QQ watchdog controls

| Variable | Default | Purpose |
| --- | --- | --- |
| `QQ_FLAGS` | `--no-sandbox --disable-notifications --disable-features=DesktopNotifications --ozone-platform=x11` | Launch flags passed to `qq` |
| `QQ_WATCHDOG_ENABLED` | `true` | Enable the background QQ watchdog |
| `QQ_WATCHDOG_INTERVAL_SEC` | `30` | Watchdog polling interval |
| `QQ_WATCHDOG_THRESHOLD` | `220` | Restart QQ when X11 pairs reach or exceed this value |
| `QQ_WATCHDOG_RECOVERY_TARGET` | `170` | Recovery window threshold used for logging |
| `QQ_WATCHDOG_RESTART_COOLDOWN_SEC` | `120` | Minimum time between automatic QQ restarts |

### Other important settings

- `PUID` and `PGID` control ownership of files written into `./config`
- `CUSTOM_USER` and `PASSWORD` control optional web authentication
- `MAX_RESOLUTION` sets the upper desktop resolution exposed by Selkies
- `shm_size` is set to `2gb` and should stay at or above `1gb`

## Architecture

### Repository layout

```text
Preset-Selkies/
├── Dockerfile
├── docker-compose.yml
├── assets/
│   ├── Background.png
│   └── app-icon.png
├── config/
│   ├── alacritty.toml
│   └── menu.xml
└── scripts/
    ├── app-restart.sh
    ├── autostart-apps.sh
    ├── clipboard-sync.sh
    ├── qq-watchdog.sh
    ├── system-start.sh
    └── x11-diagnose.sh
```

### Startup flow

```text
Openbox autostart
  -> system-start.sh
  -> autostart-apps.sh
  -> app-restart.sh
```

What each script does:

- [`scripts/system-start.sh`](./scripts/system-start.sh) configures Openbox, syncs defaults into `/config`, applies wallpaper, starts the tray, starts clipboard sync, then triggers app autostart
- [`scripts/autostart-apps.sh`](./scripts/autostart-apps.sh) checks `AUTO_START_*` variables and launches apps
- [`scripts/app-restart.sh`](./scripts/app-restart.sh) enforces a 5-second debounce window and avoids duplicate processes
- [`scripts/qq-watchdog.sh`](./scripts/qq-watchdog.sh) monitors X11 socket usage and restarts QQ when it crosses the configured threshold
- [`scripts/clipboard-sync.sh`](./scripts/clipboard-sync.sh) mirrors clipboard text between X selections
- [`scripts/x11-diagnose.sh`](./scripts/x11-diagnose.sh) helps inspect X11 client growth

### Persistence

Host `./config` is mounted to container `/config` and stores:

- application data for WeChat, QQ, and Thorium
- Openbox and Alacritty configuration copied from `/defaults`
- downloads and desktop files
- `autostart.log` at `/config/.config/openbox/autostart.log`

## Troubleshooting

### View startup logs

```bash
docker exec preset-selkies tail -f /config/.config/openbox/autostart.log
```

### Restart an app manually

```bash
docker exec preset-selkies bash /scripts/app-restart.sh /usr/bin/wechat
docker exec preset-selkies bash /scripts/app-restart.sh /usr/bin/qq --no-sandbox
docker exec preset-selkies bash /scripts/app-restart.sh /usr/bin/thorium-browser --no-sandbox --test-type --disable-infobars
```

### Inspect QQ X11 growth

```bash
docker exec preset-selkies bash /scripts/x11-diagnose.sh
docker exec preset-selkies bash /scripts/x11-diagnose.sh --watch 2 30
```

### Common failure patterns

- Blank or unstable desktop stream: confirm `shm_size` is still at least `1gb`
- QQ eventually breaks the stream: inspect `QQ_WATCHDOG_*` settings and `autostart.log`
- App does not start: verify the binary exists inside the container and check the startup log
- Clipboard text does not sync: inspect whether `clipboard-sync.sh` is running inside the container

## For AI Agents

Use [`AGENT-README.md`](./AGENT-README.md) as the canonical automation and codebase reference.

[`LLM_README.md`](./LLM_README.md) is kept only as a compatibility entry point for older prompts and tooling.

## License

This project extends [LinuxServer docker-baseimage-selkies](https://github.com/linuxserver/docker-baseimage-selkies) and is distributed under GPL-3.0.

- Preset-Selkies modifications: Bitfennec
- Base image: LinuxServer.io
- Details: [LICENSE](./LICENSE), [NOTICE](./NOTICE)
