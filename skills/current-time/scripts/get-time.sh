#!/bin/bash

TIMEZONE_FILE="$HOME/.claude/current-timezone"

if [ $# -eq 1 ]; then
    TZ_NAME="$1"
    TZ_PATH="/usr/share/zoneinfo/$TZ_NAME"
    if [ -f "$TZ_PATH" ]; then
        echo "$TZ_NAME" > "$TIMEZONE_FILE"
        echo "Timezone configured: $TZ_NAME"
        TZ="$TZ_NAME" date
    else
        if [ -d "$TZ_PATH" ]; then
            echo "Error: '$TZ_NAME' is a region prefix, not a valid timezone. Try e.g. '$TZ_NAME/City'." >&2
        else
            echo "Error: '$TZ_NAME' is not a valid timezone (not found in /usr/share/zoneinfo/)." >&2
        fi
        exit 1
    fi
else
    if [ -f "$TIMEZONE_FILE" ]; then
        TIMEZONE=$(cat "$TIMEZONE_FILE")
    else
        TIMEZONE="UTC"
    fi
    echo "Timezone: $TIMEZONE"
    TZ="$TIMEZONE" date
fi
