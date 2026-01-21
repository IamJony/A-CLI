#!/bin/bash
# search.sh - Búsqueda 

# Cargar configuración
source config.sh 2>/dev/null || {
    echo "Error: No se encuentra config.sh"
    exit 1
}

# Parámetros
SEARCH_TERM="$1"

if [ -z "$SEARCH_TERM" ]; then
    echo "Uso: $0 \"término de búsqueda\""
    exit 1
fi

# Asegurar que tenemos token
check_token

if [ -z "$CSRF_TOKEN" ]; then
    echo "Error: No se pudo obtener token CSRF"
    exit 1
fi

# Codificar término para URL
ENCODED_TERM=$(echo "$SEARCH_TERM" | sed 's/ /+/g')

echo "Buscando: $SEARCH_TERM"
echo "Token CSRF: ${CSRF_TOKEN:0:10}..."

# Realizar búsqueda
curl -s "$API_SEARCH" \
    -X POST \
    -H "User-Agent: $USER_AGENT" \
    -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
    -H "X-Requested-With: XMLHttpRequest" \
    -H "Referer: $BASE_URL/buscar/$ENCODED_TERM" \
    -H "Origin: $BASE_URL" \
    -b "$COOKIE_FILE" \
    --data "_token=$CSRF_TOKEN&q=$SEARCH_TERM" | jq . > "$TEMP_DIR/search.json"
