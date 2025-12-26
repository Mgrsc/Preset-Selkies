# Preset-Selkies Desktop

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Docker Image](https://img.shields.io/badge/Docker-ghcr.io-blue?logo=docker)](https://github.com/Mgrsc/Preset-Selkies/pkgs/container/preset-selkies)
[![Build Status](https://github.com/Mgrsc/Preset-Selkies/actions/workflows/build-docker.yml/badge.svg)](https://github.com/Mgrsc/Preset-Selkies/actions/workflows/build-docker.yml)

基于 [LinuxServer Selkies](https://github.com/linuxserver/docker-baseimage-selkies) 的容器化桌面环境，预装微信、QQ 和 Thorium 浏览器。

## ✨ 主要特性

- 🖥️ 浏览器直接访问完整 Linux 桌面
- 💬 预装微信、QQ 和 Thorium 浏览器
- 🎯 环境变量控制应用自启动
- 🇨🇳 中文环境开箱即用（时区、字体）
- 📦 数据自动持久化

## 🚀 快速开始

```bash
# 1. 克隆仓库
git clone https://github.com/Mgrsc/Preset-Selkies.git
cd Preset-Selkies

# 2. 按需修改 docker-compose.yml 中的内容
nano docker-compose.yml

# 3. 启动容器
docker-compose up -d
```

## ⚙️ 应用自启动配置

本项目新增的环境变量，用于控制应用自动启动：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `AUTO_START_WECHAT` | `true` | 自动启动微信 |
| `AUTO_START_QQ` | `false` | 自动启动 QQ |
| `AUTO_START_THORIUM` | `false` | 自动启动 Thorium 浏览器 |

在 `docker-compose.yml` 中修改：

```yaml
environment:
  - AUTO_START_WECHAT=true
  - AUTO_START_QQ=true
  - AUTO_START_THORIUM=false
```

> **其他配置**（分辨率、GPU、编码器等）请参考：[LinuxServer Selkies 官方文档](https://docs.linuxserver.io/images/docker-baseimage-selkies)

## 📁 项目结构

```
Preset-Selkies/
├── scripts/                # 启动脚本（本项目核心）
│   ├── system-start.sh     # 系统初始化
│   ├── autostart-apps.sh   # 应用自启动管理
│   └── app-restart.sh      # 单应用启动守护（防抖、日志）
├── assets/                 # 资源文件
│   ├── Background.png      # 桌面壁纸
│   └── app-icon.png        # Web 图标
├── config/                 # Openbox 配置
└── docker-compose.yml      # 容器配置（带详细注释）
```

## 🔧 脚本设计

三层启动架构，核心特性：

```
Openbox 启动
    ↓
system-start.sh         # 系统初始化（壁纸、托盘）
    ↓
autostart-apps.sh       # 根据环境变量启动应用
    ↓
app-restart.sh          # 单应用守护（防抖、进程检测）
```

- **防抖机制**: 5秒内不会重复启动同一应用
- **幂等性**: 检测应用是否已运行，避免多开
- **可扩展**: 轻松添加新应用（见下方）

## 📦 数据持久化

所有数据自动保存到 `./config` 目录：

```
./config/
├── .config/
│   ├── wechat/              # 微信数据
│   ├── QQ/                  # QQ 数据
│   ├── thorium/             # Thorium 数据
│   └── openbox/
│       └── autostart.log    # 启动日志（排查问题看这里）
├── Downloads/               # 下载文件
└── Desktop/                 # 桌面文件
```

## 🔧 故障排除

### 查看启动日志

容器首次启动后会在宿主机的 `./config/.config/openbox/autostart.log` 生成日志。查看实时日志：

```bash
# 如使用不同容器名，请替换 preset-selkies
docker exec preset-selkies tail -f /config/.config/openbox/autostart.log
```

### 手动重启应用

```bash
docker exec preset-selkies /scripts/app-restart.sh /usr/bin/wechat
docker exec preset-selkies /scripts/app-restart.sh /usr/bin/qq --no-sandbox
```

## 🎯 添加自定义应用

1. `git clone https://github.com/Mgrsc/Preset-Selkies.git && cd Preset-Selkies`
2. 安装并运行 [Codex](https://chatgpt.com/zh-Hans-CN/features/codex/) 或 [Claude Code](https://code.claude.com/docs/en/overview)，在项目根目录打开后让它先阅读 `LLM_README.md`。
3. 把你的应用下载地址告诉它（例如 `xxxx`），让它按照 `LLM_README.md` 里的流程帮你添加并配置好自启动。

## 📄 许可证

本项目基于 [LinuxServer docker-baseimage-selkies](https://github.com/linuxserver/docker-baseimage-selkies)，遵循 GPL-3.0 许可证。

- 本修改版 © 2025 Bitfennec
- 基础镜像 © LinuxServer.io
- 详见 [LICENSE](./LICENSE) 和 [NOTICE](./NOTICE)

## 🔗 相关链接

- [LinuxServer Selkies 官方文档](https://docs.linuxserver.io/images/docker-baseimage-selkies) - 分辨率、GPU、编码器等配置
- [Selkies GStreamer 项目](https://github.com/selkies-project/selkies-gstreamer)
- [thorium](https://github.com/Alex313031/thorium)