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
        QQ_FLAGS_VALUE="${QQ_FLAGS:---no-sandbox --disable-notifications --disable-features=DesktopNotifications --ozone-platform=x11}"
        QQ_ARGS=()
        if [ -n "$QQ_FLAGS_VALUE" ]; then
            read -r -a QQ_ARGS <<< "$QQ_FLAGS_VALUE"
        fi
        log "Starting QQ with flags: ${QQ_FLAGS_VALUE}"
        bash /scripts/app-restart.sh /usr/bin/qq "${QQ_ARGS[@]}" >> "$LOG_FILE" 2>&1
        if [ "${QQ_WATCHDOG_ENABLED:-true}" = "true" ]; then
            log "Starting QQ watchdog..."
            bash /scripts/qq-watchdog.sh >> "$LOG_FILE" 2>&1 &
            QQ_WATCHDOG_PID=$!
            log "QQ watchdog started (PID: $QQ_WATCHDOG_PID)"
        else
            log "QQ watchdog is disabled by QQ_WATCHDOG_ENABLED"
        fi
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
