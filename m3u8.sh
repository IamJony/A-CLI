#!/bin/bash
# get_m3u8.sh - Extrae URL m3u8 de reproductor

source config.sh 2>/dev/null || {
    echo "Error: No config.sh"
    exit 1
}

[ -z "$1" ] && { echo "Uso: $0 <url>"; exit 1; }

URL="$1"
curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" "$URL" | \
    grep -o "atob('[^']*')" | \
    sed "s/.*atob('\([^']*\)').*/\1/" | \
    base64 -d | \
    grep "\.m3u8" > "$TEMP_DIR/stream.m3u8"

if [ -s "$TEMP_DIR/stream.m3u8" ]; then
    echo "{\"m3u8\": \"$(head -1 "$TEMP_DIR/stream.m3u8")\"}" > "$TEMP_DIR/stream.json"
    echo "$(head -1 "$TEMP_DIR/stream.m3u8")"
else
    echo '{"m3u8": null}' > "$TEMP_DIR/stream.json"
    echo "❌ No encontrado lista m3u8"
fi