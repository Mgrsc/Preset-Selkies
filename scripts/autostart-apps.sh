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

if [ "${AUTO_START_THORIUM:-false}" = "true" ]; then
    if [ -x /usr/bin/thorium-browser ]; then
        log "Starting Thorium Browser..."
        bash /scripts/app-restart.sh /usr/bin/thorium-browser --no-sandbox --test-type --disable-infobars  >> "$LOG_FILE" 2>&1
    else
        log "Warning: Thorium Browser not found or not executable"
    fi
fi

log "Auto-start applications completed"
