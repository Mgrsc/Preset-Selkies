#!/usr/bin/env bash

set -uo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: $0 <application_path> [arguments...]" >&2
    echo "Example: $0 /usr/bin/wechat" >&2
    echo "Example: $0 /usr/bin/qq --no-sandbox" >&2
    exit 1
fi

APP_PATH="$1"
shift
APP_ARGS=("$@")
APP_NAME=$(basename "$APP_PATH")

LOCK_FILE="/tmp/${APP_NAME}-restart.lock"
LOCK_TIMEOUT=5

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${APP_NAME}] $*" >&2
}

if [ -f "$LOCK_FILE" ]; then
    LOCK_AGE=$(($(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0)))
    if [ "$LOCK_AGE" -lt "$LOCK_TIMEOUT" ]; then
        log "Already being restarted, please wait..."
        exit 0
    else
        log "Stale lock file detected, removing..."
        rm -f "$LOCK_FILE"
    fi
fi

touch "$LOCK_FILE"

trap 'rm -f "$LOCK_FILE"' EXIT INT TERM

if [ ! -x "$APP_PATH" ]; then
    log "ERROR: Application not found or not executable: $APP_PATH"
    exit 1
fi

if pidof -x "$APP_NAME" > /dev/null 2>&1; then
    log "Application is already running, no action needed"
    exit 0
fi

log "Application not running, starting..."

sleep 0.5

log "Starting application with args: ${APP_ARGS[*]}"
if [ ${#APP_ARGS[@]} -eq 0 ]; then
    nohup "$APP_PATH" > /dev/null 2>&1 &
else
    nohup "$APP_PATH" "${APP_ARGS[@]}" > /dev/null 2>&1 &
fi

log "Application started in background"

sleep 2

log "Restart completed successfully"
