#!/bin/bash
while clipnotify; do
    content=$(xclip -o -selection clipboard 2>/dev/null)
    if [ ! -z "$content" ]; then
        echo -n "$content" | xclip -i -selection clipboard
        echo -n "$content" | xclip -i -selection primary
    fi
done
