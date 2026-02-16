FROM ghcr.io/linuxserver/baseimage-selkies:ubuntunoble

LABEL org.opencontainers.image.title="agent-selkies Desktop" \
      org.opencontainers.image.authors="Bitfennec" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.licenses="GPL-3.0" \
      org.opencontainers.image.source="https://github.com/Mgrsc/agent-selkies" \
      org.opencontainers.image.url="https://github.com/Mgrsc/agent-selkies" \
      org.opencontainers.image.base.name="ghcr.io/linuxserver/baseimage-selkies:ubuntunoble"

ARG WECHAT_VERSION="WeChatLinux_x86_64.deb"
ARG QQ_VERSION="QQ_3.2.25_260205_amd64_01.deb"
ARG WECHAT_URL="https://dldir1v6.qq.com/weixin/Universal/Linux/${WECHAT_VERSION}"
ARG QQ_URL="https://dldir1v6.qq.com/qqfile/qq/QQNT/Linux/${QQ_VERSION}"
ARG DEBIAN_FRONTEND="noninteractive"

RUN export DEBIAN_FRONTEND="${DEBIAN_FRONTEND}" && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        fonts-noto-cjk \
        stalonetray \
        feh \
        curl \
        ca-certificates \
        vim \
        alacritty \
        ristretto \
        gnupg \
        wget \
        locales \
        language-pack-zh-hans \
        autocutsel && \
    locale-gen zh_CN.UTF-8 && \
    wget -qO- 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x5301FA4FD93244FBC6F6149982BB6851C64F6880' | gpg --dearmor | tee /etc/apt/trusted.gpg.d/xtradeb-apps.gpg > /dev/null && \
    echo "deb [signed-by=/etc/apt/trusted.gpg.d/xtradeb-apps.gpg] http://ppa.launchpad.net/xtradeb/apps/ubuntu noble main" | tee /etc/apt/sources.list.d/xtradeb-apps.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ungoogled-chromium \
        ungoogled-chromium-l10n && \
    curl -fsSL --retry 3 --retry-delay 2 -o /tmp/wechat.deb "${WECHAT_URL}" || \
        { echo "ERROR: Failed to download WeChat from ${WECHAT_URL}"; exit 1; } && \
    curl -fsSL --retry 3 --retry-delay 2 -o /tmp/qq.deb "${QQ_URL}" || \
        { echo "ERROR: Failed to download QQ from ${QQ_URL}"; exit 1; } && \
    [ -f /tmp/wechat.deb ] && [ -s /tmp/wechat.deb ] || { echo "ERROR: WeChat download corrupted"; exit 1; } && \
    [ -f /tmp/qq.deb ] && [ -s /tmp/qq.deb ] || { echo "ERROR: QQ download corrupted"; exit 1; } && \
    dpkg -i /tmp/wechat.deb /tmp/qq.deb || true && \
    apt-get install -y --no-install-recommends -f && \
    rm -f /tmp/wechat.deb /tmp/qq.deb && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

ENV TZ="Asia/Shanghai" \
    LC_ALL="zh_CN.UTF-8" \
    AUTO_START_WECHAT="true" \
    AUTO_START_QQ="false" \
    AUTO_START_CHROMIUM="false" \
    SELKIES_CLIPBOARD_ENABLED="true" \
    SELKIES_ENABLE_BINARY_CLIPBOARD="true"

COPY assets/app-icon.png /usr/share/selkies/www/icon.png
COPY assets/Background.png /usr/share/backgrounds/Background.png
COPY config/menu.xml /defaults/menu.xml
COPY config/alacritty.toml /defaults/alacritty.toml
COPY scripts/ /scripts/

RUN chmod 755 /scripts/*.sh && \
    cp /scripts/system-start.sh /defaults/autostart && \
    chmod 755 /defaults/autostart
