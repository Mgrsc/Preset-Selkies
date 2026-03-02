#!/usr/bin/env bash

set -u

DISPLAY_ID="${DISPLAY:-:1}"
DISPLAY_NUM="${DISPLAY_ID#:}"
WATCH_MODE=0
WATCH_INTERVAL=1
WATCH_TIMES=0
WARN_THRESHOLD=220
CRIT_THRESHOLD=250

if [ "${1:-}" = "--watch" ]; then
    WATCH_MODE=1
    WATCH_INTERVAL="${2:-1}"
    WATCH_TIMES="${3:-0}"
fi

ts() {
    date '+%Y-%m-%d %H:%M:%S'
}

log() {
    echo "[$(ts)] [x11-diagnose] $*"
}

count_process() {
    local pattern="$1"
    local out
    out="$(pgrep -fc "$pattern" 2>/dev/null || true)"
    case "$out" in
        ''|*[!0-9]*)
            echo 0
            ;;
        *)
            echo "$out"
            ;;
    esac
}

level_by_pairs() {
    local pairs="$1"
    if [ "$pairs" -ge "$CRIT_THRESHOLD" ]; then
        echo CRITICAL
    elif [ "$pairs" -ge "$WARN_THRESHOLD" ]; then
        echo WARNING
    else
        echo OK
    fi
}

count_estab_pairs() {
    ss -xna | awk -v d="@/tmp/.X11-unix/X${DISPLAY_NUM}" -v d2="/tmp/.X11-unix/X${DISPLAY_NUM}" '
        $1 ~ /^u_/ && $2 == "ESTAB" && ($5 == d || $5 == d2) { n++ }
        END { print n + 0 }
    '
}

collect_inodes() {
    ss -xna | awk -v d="@/tmp/.X11-unix/X${DISPLAY_NUM}" -v d2="/tmp/.X11-unix/X${DISPLAY_NUM}" '
        $1 ~ /^u_/ && $2 == "ESTAB" && ($5 == d || $5 == d2) {
            if ($6 ~ /^[0-9]+$/) print $6
            if ($8 ~ /^[0-9]+$/) print $8
        }
    ' | sort -u
}

map_inode_owners() {
    local inode_file="$1"
    local owner_file="$2"
    : > "$owner_file"

    while IFS= read -r ino; do
        [ -n "$ino" ] || continue
        for fd in /proc/[0-9]*/fd/*; do
            [ -e "$fd" ] || continue
            local lk
            lk="$(readlink "$fd" 2>/dev/null || true)"
            [ "$lk" = "socket:[$ino]" ] || continue
            local pid comm cmdline
            pid="$(echo "$fd" | cut -d/ -f3)"
            comm="$(cat "/proc/${pid}/comm" 2>/dev/null || echo '?')"
            cmdline="$(tr '\0' ' ' < "/proc/${pid}/cmdline" 2>/dev/null || true)"
            [ -n "$cmdline" ] || cmdline="$comm"
            echo "${pid}|${comm}|${cmdline}|${ino}" >> "$owner_file"
        done
    done < "$inode_file"
}

print_top_owners() {
    local owner_file="$1"
    if [ ! -s "$owner_file" ]; then
        log "inode 对应进程未解析到，可能是 /proc 可见性限制或命名空间差异"
        return 0
    fi

    sort -u "$owner_file" > "${owner_file}.uniq"
    awk -F'|' '
        {
            key = $1 "|" $2 "|" $3
            c[key]++
        }
        END {
            for (k in c) {
                split(k, p, "|")
                printf "%5d pid=%s comm=%s cmd=%s\n", c[k], p[1], p[2], p[3]
            }
        }
    ' "${owner_file}.uniq" | sort -nr | head -n 40
}

print_basic() {
    local pairs xclip_count clipnotify_count
    pairs="$(count_estab_pairs)"
    xclip_count="$(count_process xclip)"
    clipnotify_count="$(count_process clipnotify)"
    log "display=${DISPLAY_ID}"
    log "x11_estab_pairs=${pairs} level=$(level_by_pairs "$pairs")"
    log "xclip=${xclip_count} clipnotify=${clipnotify_count}"
}

run_once() {
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    local inode_file owner_file
    inode_file="${tmp_dir}/x11.inodes"
    owner_file="${tmp_dir}/x11.owners"

    print_basic
    collect_inodes > "$inode_file"
    log "x11_related_inodes=$(wc -l < "$inode_file")"
    map_inode_owners "$inode_file" "$owner_file"
    print_top_owners "$owner_file"

    rm -rf "$tmp_dir"
}

run_watch() {
    local i=0
    while true; do
        local pairs xclip_count clipnotify_count
        i=$((i + 1))
        pairs="$(count_estab_pairs)"
        xclip_count="$(count_process xclip)"
        clipnotify_count="$(count_process clipnotify)"
        log "watch_tick=${i} x11_estab_pairs=${pairs} level=$(level_by_pairs "$pairs") xclip=${xclip_count} clipnotify=${clipnotify_count}"
        if [ "$WATCH_TIMES" -gt 0 ] && [ "$i" -ge "$WATCH_TIMES" ]; then
            break
        fi
        sleep "$WATCH_INTERVAL"
    done
}

if [ "$WATCH_MODE" -eq 1 ]; then
    run_watch
else
    run_once
fi
