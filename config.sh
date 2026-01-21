#!/bin/bash
# Configuracion inicial de A-CLI by IamJony

# URLs base
BASE64_BASE_URL="aHR0cHM6Ly9qa2FuaW1lLm5ldA=="
BASE_URL=$(echo "$BASE64_BASE_URL" | base64 -d)
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

# Función para obtener cookies y token
get_cookies_and_token() {
    # echo "Obteniendo cookies y token CSRF..."
    
    # Descargar página principal
    curl -s -c "$COOKIE_FILE" "$BASE_URL" \
        -H "User-Agent: $USER_AGENT" \
        -o "$TEMP_HTML"
    
    # Extraer token CSRF del HTML
    CSRF_TOKEN=$(grep -o 'name="csrf-token" content="[^"]*"' "$TEMP_HTML" | \
                 sed 's/.*content="//;s/"//')
    
    # Guardar token
    if [ -n "$CSRF_TOKEN" ]; then
        echo "CSRF_TOKEN=$CSRF_TOKEN" > "$TOKEN_FILE"
        #echo "Token obtenido: ${CSRF_TOKEN:0:10}..."
    else
        echo "Error: No se pudo extraer token CSRF"
    fi
}

# Cargar token si existe
load_token() {
    if [ -f "$TOKEN_FILE" ]; then
        source "$TOKEN_FILE"
    fi
}

# Verificar y actualizar token si es necesario
check_token() {
    if [ ! -f "$TOKEN_FILE" ] || [ -z "$CSRF_TOKEN" ]; then
        get_cookies_and_token
    fi
}

# Inicializar
check_token
