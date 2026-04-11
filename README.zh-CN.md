# Preset-Selkies Desktop

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Docker Image](https://img.shields.io/badge/Docker-ghcr.io-blue?logo=docker)](https://github.com/Mgrsc/Preset-Selkies/pkgs/container/preset-selkies)
[![Build Status](https://github.com/Mgrsc/Preset-Selkies/actions/workflows/build-docker.yml/badge.svg)](https://github.com/Mgrsc/Preset-Selkies/actions/workflows/build-docker.yml)

> 基于 LinuxServer Selkies 的容器化 Linux 桌面，预装微信、QQ 和 Thorium，默认适配中文环境，面向浏览器远程桌面场景。

English documentation: [README.md](./README.md)

## 目录
- [特性](#特性)
- [快速开始](#快速开始)
- [配置](#配置)
- [架构](#架构)
- [故障排查](#故障排查)
- [面向 AI Agent](#面向-ai-agent)
- [许可证](#许可证)

## 特性

- 通过 `3000` 端口上的 HTTPS 在浏览器中访问完整 Linux 桌面
- 预装 `wechat`、`qq` 和 `thorium-browser`
- 通过环境变量控制应用是否自启动
- 默认中文地区配置，并内置 CJK 字体
- 通过 `/config` 挂载持久化用户数据
- 使用 `clipnotify` 和 `xclip` 在 X 剪贴板选择之间同步文本
- 提供 QQ X11 连接看门狗，用于缓解 `Maximum number of clients reached`

## 快速开始

### 前置条件

- 已安装 Docker Engine 和 Compose 插件
- 如果保留默认硬件加速配置，宿主机需要提供 `/dev/dri`
- 使用可访问 `https://localhost:3000` 的现代浏览器

### 直接运行已发布镜像

```bash
git clone https://github.com/Mgrsc/Preset-Selkies.git
cd Preset-Selkies
docker compose up -d
```

打开 `https://localhost:3000`。

如果 [`docker-compose.yml`](./docker-compose.yml) 中设置了 `PASSWORD`，使用 `CUSTOM_USER` 和 `PASSWORD` 登录；如果 `PASSWORD` 为空，则 Web 桌面不会显示额外的应用层登录提示。

### 修改镜像后本地构建

```bash
docker build -t preset-selkies:local .
```

然后把 [`docker-compose.yml`](./docker-compose.yml) 里的 `image:` 改成 `preset-selkies:local` 再启动容器。

## 配置

主要运行时配置位于 [`docker-compose.yml`](./docker-compose.yml)。

### 应用自启动控制

| 变量 | 镜像内默认值 | compose 文件默认值 | 作用 |
| --- | --- | --- | --- |
| `AUTO_START_WECHAT` | `true` | `false` | 桌面启动时启动微信 |
| `AUTO_START_QQ` | `false` | `false` | 桌面启动时启动 QQ |
| `AUTO_START_THORIUM` | `false` | `false` | 桌面启动时启动 Thorium |

### QQ 看门狗控制

| 变量 | 默认值 | 作用 |
| --- | --- | --- |
| `QQ_FLAGS` | `--no-sandbox --disable-notifications --disable-features=DesktopNotifications --ozone-platform=x11` | 传给 `qq` 的启动参数 |
| `QQ_WATCHDOG_ENABLED` | `true` | 是否启用后台 QQ 看门狗 |
| `QQ_WATCHDOG_INTERVAL_SEC` | `30` | 看门狗轮询间隔 |
| `QQ_WATCHDOG_THRESHOLD` | `220` | X11 连接数达到该值时自动重启 QQ |
| `QQ_WATCHDOG_RECOVERY_TARGET` | `170` | 用于日志记录的恢复观察阈值 |
| `QQ_WATCHDOG_RESTART_COOLDOWN_SEC` | `120` | 两次自动重启之间的最小间隔 |

### 其他关键设置

- `PUID` 和 `PGID` 控制写入 `./config` 的文件属主
- `CUSTOM_USER` 和 `PASSWORD` 控制可选的 Web 登录认证
- `MAX_RESOLUTION` 控制 Selkies 暴露的最大桌面分辨率
- `shm_size` 当前为 `2gb`，不应低于 `1gb`

## 架构

### 仓库结构

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

### 启动流程

```text
Openbox autostart
  -> system-start.sh
  -> autostart-apps.sh
  -> app-restart.sh
```

各脚本职责：

- [`scripts/system-start.sh`](./scripts/system-start.sh) 配置 Openbox、将默认配置同步到 `/config`、设置壁纸、启动托盘、启动剪贴板同步，并触发应用自启动
- [`scripts/autostart-apps.sh`](./scripts/autostart-apps.sh) 读取 `AUTO_START_*` 变量并启动应用
- [`scripts/app-restart.sh`](./scripts/app-restart.sh) 提供 5 秒防抖和单实例保护
- [`scripts/qq-watchdog.sh`](./scripts/qq-watchdog.sh) 监控 X11 socket 使用量并在超过阈值时重启 QQ
- [`scripts/clipboard-sync.sh`](./scripts/clipboard-sync.sh) 在 X 剪贴板选择之间同步文本
- [`scripts/x11-diagnose.sh`](./scripts/x11-diagnose.sh) 用于排查 X11 客户端数量增长

### 数据持久化

宿主机 `./config` 挂载到容器 `/config`，其中保存：

- 微信、QQ、Thorium 的应用数据
- 从 `/defaults` 同步出来的 Openbox 和 Alacritty 配置
- 下载文件和桌面文件
- 位于 `/config/.config/openbox/autostart.log` 的启动日志

## 故障排查

### 查看启动日志

```bash
docker exec preset-selkies tail -f /config/.config/openbox/autostart.log
```

### 手动重启应用

```bash
docker exec preset-selkies bash /scripts/app-restart.sh /usr/bin/wechat
docker exec preset-selkies bash /scripts/app-restart.sh /usr/bin/qq --no-sandbox
docker exec preset-selkies bash /scripts/app-restart.sh /usr/bin/thorium-browser --no-sandbox --test-type --disable-infobars
```

### 检查 QQ 的 X11 连接增长

```bash
docker exec preset-selkies bash /scripts/x11-diagnose.sh
docker exec preset-selkies bash /scripts/x11-diagnose.sh --watch 2 30
```

### 常见故障模式

- 桌面画面空白或不稳定：确认 `shm_size` 仍然不小于 `1gb`
- QQ 运行一段时间后影响串流：检查 `QQ_WATCHDOG_*` 配置和 `autostart.log`
- 应用未启动：确认容器内二进制存在，并查看启动日志
- 剪贴板文本不同步：检查容器内 `clipboard-sync.sh` 是否正常运行

## 面向 AI Agent

自动化和代码库规范说明以 [`AGENT-README.md`](./AGENT-README.md) 为准。

[`LLM_README.md`](./LLM_README.md) 仅保留为旧提示词和旧工具链的兼容入口。

## 许可证

本项目基于 [LinuxServer docker-baseimage-selkies](https://github.com/linuxserver/docker-baseimage-selkies) 扩展，遵循 GPL-3.0 许可证。

- Preset-Selkies 修改部分：Bitfennec
- 基础镜像：LinuxServer.io
- 详情见 [LICENSE](./LICENSE)、[NOTICE](./NOTICE)
