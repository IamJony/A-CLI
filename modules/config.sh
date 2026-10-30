#!/bin/bash

# Configuracion inicial de A-CLI by IamJony
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTIL="$SCRIPT_DIR/util.sh"
source "$UTIL"

# URLs base
BASE_URL=$(d "66 94 94 90 89 16 5 5 64 65 75 68 67 71 79 4 68 79 94")
API_SEARCH="$BASE_URL/ajax_search"
API_CHAPTERS="$BASE_URL/ajax/episodes"

# User Agent
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64; rv:146.0) Gecko/20100101 Firefox/146.0"

# Archivos temporales 
TEMP_DIR="/tmp/TEMP_A-CLI"
COOKIE_FILE="$TEMP_DIR/cookies.txt"
TOKEN_FILE="$TEMP_DIR/tokens.txt"
TEMP_HTML="$TEMP_DIR/last_page.html"

# Crear directorio temporal
mkdir -p "$TEMP_DIR" 2>/dev/null

# Variables globales
CSRF_TOKEN=""

# Verificar si cookies y token son válidos (max 30 minutos)
verify_cookies() {
    [ ! -f "$COOKIE_FILE" ] && return 1
    [ ! -f "$TOKEN_FILE" ] && return 1
    [ ! -s "$COOKIE_FILE" ] && return 1
    
    # Verificar antigüedad del archivo (1800 segundos = 30 minutos)
    local file_time=$(stat -c %Y "$COOKIE_FILE" 2>/dev/null || echo 0)
    local current_time=$(date +%s)
    local age=$((current_time - file_time))
    
    [ $age -gt 1800 ] && return 1
    
    source "$TOKEN_FILE" 2>/dev/null
    [ -z "$CSRF_TOKEN" ] && return 1
    
    return 0
}

# Obtener nuevas cookies y token
get_cookies() {
    curl -s -c "$COOKIE_FILE" "$BASE_URL" -H "User-Agent: $USER_AGENT" -o "$TEMP_HTML"
    
    CSRF_TOKEN=$(grep -o 'name="csrf-token" content="[^"]*"' "$TEMP_HTML" | sed 's/.*content="//;s/"//')
    
    if [ -n "$CSRF_TOKEN" ]; then
        echo "CSRF_TOKEN=$CSRF_TOKEN" > "$TOKEN_FILE"
    fi
}

# Cargar token
load_token() {
    [ -f "$TOKEN_FILE" ] && source "$TOKEN_FILE"
}

# Verificar y obtener cookies solo si es necesario
check_token() {
    if verify_cookies; then
        load_token
    else
        get_cookies
    fi
}

# Inicializar
check_token
