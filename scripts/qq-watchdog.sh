#!/usr/bin/env bash

set -u

LOG_FILE="/config/.config/openbox/autostart.log"
PID_FILE="/tmp/qq-watchdog.pid"
DISPLAY_ID="${QQ_WATCHDOG_DISPLAY:-${DISPLAY:-:1}}"
DISPLAY_NUM="${DISPLAY_ID#:}"
INTERVAL_SEC="${QQ_WATCHDOG_INTERVAL_SEC:-30}"
THRESHOLD="${QQ_WATCHDOG_THRESHOLD:-220}"
RECOVERY_TARGET="${QQ_WATCHDOG_RECOVERY_TARGET:-170}"
RESTART_COOLDOWN_SEC="${QQ_WATCHDOG_RESTART_COOLDOWN_SEC:-120}"
QQ_FLAGS_VALUE="${QQ_FLAGS:---no-sandbox --disable-notifications --disable-features=DesktopNotifications --ozone-platform=x11}"
LAST_RESTART_AT=0

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [QQ-WATCHDOG] $*"
    echo "$msg" | tee -a "$LOG_FILE"
}

count_x11_pairs() {
    ss -xna | awk -v d="@/tmp/.X11-unix/X${DISPLAY_NUM}" -v d2="/tmp/.X11-unix/X${DISPLAY_NUM}" '
        $1 ~ /^u_/ && $2 == "ESTAB" && ($5 == d || $5 == d2) { n++ }
        END { print n + 0 }
    '
}

get_qq_pid() {
    pgrep -xo qq 2>/dev/null || true
}

start_qq() {
    local qq_args=()
    if [ -n "$QQ_FLAGS_VALUE" ]; then
        read -r -a qq_args <<< "$QQ_FLAGS_VALUE"
    fi
    log "Starting QQ with flags: ${QQ_FLAGS_VALUE}"
    bash /scripts/app-restart.sh /usr/bin/qq "${qq_args[@]}" >> "$LOG_FILE" 2>&1
}

stop_qq() {
    local pid
    pid="$(get_qq_pid)"
    if [ -z "$pid" ]; then
        log "QQ process not found, skip stop"
        return 0
    fi
    log "Stopping QQ process pid=${pid}"
    kill "$pid" 2>/dev/null || true
    sleep 2
    pid="$(get_qq_pid)"
    if [ -n "$pid" ]; then
        log "QQ still running after SIGTERM, sending SIGKILL pid=${pid}"
        kill -9 "$pid" 2>/dev/null || true
    fi
}

ensure_single_instance() {
    if [ -f "$PID_FILE" ]; then
        local existing_pid
        existing_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
        if [ -n "$existing_pid" ] && kill -0 "$existing_pid" 2>/dev/null; then
            log "Another QQ watchdog is already running (PID: ${existing_pid}), exiting"
            exit 0
        fi
    fi
    echo "$$" > "$PID_FILE"
}

cleanup() {
    rm -f "$PID_FILE"
}

main() {
    ensure_single_instance
    trap cleanup EXIT INT TERM

    log "QQ watchdog started: display=${DISPLAY_ID}, interval=${INTERVAL_SEC}s, threshold=${THRESHOLD}, recovery_target=${RECOVERY_TARGET}, cooldown=${RESTART_COOLDOWN_SEC}s"

    while true; do
        local now pairs qq_pid
        now="$(date +%s)"
        pairs="$(count_x11_pairs)"
        qq_pid="$(get_qq_pid)"
        log "heartbeat: x11_pairs=${pairs}, qq_pid=${qq_pid:-none}"

        if [ "$pairs" -ge "$THRESHOLD" ]; then
            if [ $((now - LAST_RESTART_AT)) -lt "$RESTART_COOLDOWN_SEC" ]; then
                log "threshold reached but cooldown active: x11_pairs=${pairs}, cooldown_left=$((RESTART_COOLDOWN_SEC - (now - LAST_RESTART_AT)))s"
            else
                log "threshold reached: x11_pairs=${pairs} >= ${THRESHOLD}, restarting QQ"
                stop_qq
                sleep 2
                start_qq
                LAST_RESTART_AT="$now"
            fi
        elif [ "$pairs" -ge "$RECOVERY_TARGET" ]; then
            log "recovery window: x11_pairs=${pairs} >= ${RECOVERY_TARGET}"
        fi

        sleep "$INTERVAL_SEC"
    done
}

main
