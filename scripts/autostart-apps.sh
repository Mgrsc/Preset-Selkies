#!/usr/bin/env bash

set -eu

LOG_FILE="/config/.config/openbox/autostart.log"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [AUTOSTART] $*"
    echo "$msg" | tee -a "$LOG_FILE"
}

log "Starting auto-start applications..."

if [ "${AUTO_START_WECHAT:-false}" = "true" ]; then
    if [ -x /usr/bin/wechat ]; then
        log "Starting WeChat..."
        bash /scripts/app-restart.sh /usr/bin/wechat >> "$LOG_FILE" 2>&1
    else
        log "Warning: WeChat not found or not executable"
    fi
fi

if [ "${AUTO_START_QQ:-false}" = "true" ]; then
    if [ -x /usr/bin/qq ]; then
        log "Starting QQ..."
        bash /scripts/app-restart.sh /usr/bin/qq --no-sandbox >> "$LOG_FILE" 2>&1
    else
        log "Warning: QQ not found or not executable"
    fi
fi

if [ "${AUTO_START_CHROMIUM:-false}" = "true" ]; then
    if [ -x /usr/bin/ungoogled-chromium ]; then
        log "Starting Ungoogled Chromium..."
        LANGUAGE=zh_CN:zh:en bash /scripts/app-restart.sh /usr/bin/ungoogled-chromium --no-sandbox --test-type --disable-infobars --lang=zh-CN >> "$LOG_FILE" 2>&1
    else
        log "Warning: Ungoogled Chromium not found or not executable"
    fi
fi

log "Auto-start applications completed"
