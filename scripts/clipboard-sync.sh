#!/bin/bash
while clipnotify; do
    targets=$(xclip -o -selection clipboard -t TARGETS 2>/dev/null)
    if [ -n "$targets" ] && echo "$targets" | grep -q 'image/' && ! echo "$targets" | grep -q 'UTF8_STRING\|STRING\|TEXT'; then
        continue
    fi
    content=$(xclip -o -selection clipboard 2>/dev/null | tr -d '\r')
    if [ -n "$content" ]; then
        echo -n "$content" | xclip -i -selection clipboard
        echo -n "$content" | xclip -i -selection primary
    fi
done
