#!/usr/bin/env bash

set -eu

CONFIG_DIR="/config/.config/openbox"
RC_XML="$CONFIG_DIR/rc.xml"
WALLPAPER_DIR="/usr/share/backgrounds"
DEFAULT_WALLPAPER="Background.png"
LOG_FILE="$CONFIG_DIR/autostart.log"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [SYSTEM] $*"
    echo "$msg" | tee -a "$LOG_FILE"
}

log "Starting system initialization..."

mkdir -p "$CONFIG_DIR"

configure_openbox_dock() {
    log "Configuring OpenBox dock..."

    if [ ! -f "$RC_XML" ]; then
        log "Creating default OpenBox configuration..."
        cp /etc/xdg/openbox/rc.xml "$RC_XML"
    fi

    if grep -A20 "<dock>" "$RC_XML" | grep -qE "<noStrut>no</noStrut>|<position>TopLeft</position>"; then
        log "Updating dock configuration..."
        sed -i '/<dock>/,/<\/dock>/{
            s|<noStrut>no</noStrut>|<noStrut>yes</noStrut>|
            s|<position>TopLeft</position>|<position>Bottom</position>|
        }' "$RC_XML"

        if pgrep -x openbox > /dev/null 2>&1; then
            openbox --reconfigure
        fi
    fi
}

update_openbox_menu() {
    log "Updating OpenBox menu..."

    if [ ! -f "$CONFIG_DIR/menu.xml" ] || ! cmp -s /defaults/menu.xml "$CONFIG_DIR/menu.xml"; then
        cp /defaults/menu.xml "$CONFIG_DIR/menu.xml"

        if pgrep -x openbox > /dev/null 2>&1; then
            openbox --reconfigure
        fi
    fi
}

update_alacritty_config() {
    log "Updating Alacritty configuration..."
    local ALACRITTY_CONFIG_DIR="/config/.config/alacritty"
    mkdir -p "$ALACRITTY_CONFIG_DIR"
    
    if [ ! -f "$ALACRITTY_CONFIG_DIR/alacritty.toml" ] || ! cmp -s /defaults/alacritty.toml "$ALACRITTY_CONFIG_DIR/alacritty.toml"; then
        cp /defaults/alacritty.toml "$ALACRITTY_CONFIG_DIR/alacritty.toml"
        log "Alacritty configuration updated"
    fi
}

set_wallpaper() {
    local wallpaper_path="$WALLPAPER_DIR/$DEFAULT_WALLPAPER"

    if [ ! -f "$wallpaper_path" ]; then
        return 0
    fi

    log "Setting wallpaper configuration..."

    if command -v feh > /dev/null 2>&1; then
        feh --bg-fill "$wallpaper_path" 2>/dev/null

        (
            prev_res=$(xrandr 2>/dev/null | grep "connected primary" | awk '{print $4}' | head -1)

            while true; do
                sleep 5

                if ! pgrep -x openbox > /dev/null 2>&1; then
                    log "Wallpaper monitor exiting (openbox not running)"
                    break
                fi

                curr_res=$(xrandr 2>/dev/null | grep "connected primary" | awk '{print $4}' | head -1)

                if [ -n "$curr_res" ] && [ "$curr_res" != "$prev_res" ]; then
                    prev_res="$curr_res"

                    if [ -f "$HOME/.fehbg" ]; then
                        sh "$HOME/.fehbg" 2>/dev/null && \
                        log "Wallpaper reapplied for resolution: $curr_res"
                    fi
                fi
            done
        ) &

        WALLPAPER_MONITOR_PID=$!
        log "Wallpaper monitor started (PID: $WALLPAPER_MONITOR_PID)"
    fi
}


start_system_tray() {
    log "Starting system tray..."

    pkill -x stalonetray 2>/dev/null || true
    sleep 0.5

    stalonetray --dockapp-mode simple > /dev/null 2>&1 &
    TRAY_PID=$!

    sleep 0.3
    if kill -0 "$TRAY_PID" 2>/dev/null; then
        log "System tray started successfully (PID: $TRAY_PID)"
    else
        log "Warning: System tray failed to start"
    fi
}

start_clipboard_sync() {
    log "Starting clipboard synchronization..."
    if command -v autocutsel > /dev/null 2>&1; then
        autocutsel -s PRIMARY -fork
        autocutsel -s CLIPBOARD -fork
        log "Clipboard sync started (PRIMARY <-> CLIPBOARD)"
    else
        log "Warning: autocutsel not found, clipboard sync disabled"
    fi
}

main() {
    configure_openbox_dock
    update_openbox_menu
    update_alacritty_config
    sleep 2
    set_wallpaper
    start_system_tray
    start_clipboard_sync
    sleep 1

    log "Starting auto-start applications..."
    sh /scripts/autostart-apps.sh
    log "Auto-start applications completed"

    log "System initialization completed"
}

main
