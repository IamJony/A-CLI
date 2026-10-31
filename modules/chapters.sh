#!/bin/bash

# Este script regresa el total de capitulos

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SOURCE_DIR/config.sh" || {
    echo "Error: No se encuentra config.sh"
    exit 1
}

check_token

if [ -z "$CSRF_TOKEN" ]; then
    echo "Error: No se pudo obtener token CSRF"
    exit 1
fi

# Verificar que se proporcione el ID del anime
if [ -z "$1" ]; then
    echo "Uso: $0 <id_del_anime> [numero_capitulo]"
    echo "Ejemplo: $0 1117 1"
    exit 1
fi

ANIME_ID="$1"
CHAPTER_NUM="${2:-1}"  # Usar 1 como valor por defecto si no se especifica

# URL especifica para el anime (necesaria para el Referer)
ANIME_URL="$BASE_URL/akuma-no-riddle"

# Mensajes de depuracion para verificar si esta funcionando
#echo "Obteniendo capitulos para anime ID: $ANIME_ID, capitulo: $CHAPTER_NUM"
#echo "Token CSRF: ${CSRF_TOKEN:0:10}..."
#echo "$API_CHAPTERS/$ANIME_ID/$CHAPTER_NUM"

# Ahora hacer la peticion AJAX para obtener los episodios
# (wget no soporta -X POST explicito: --post-data ya fuerza POST)

wget -q \
    --load-cookies="$COOKIE_FILE" \
    --user-agent="$USER_AGENT" \
    --header="Accept: application/json, text/javascript, */*; q=0.01" \
    --header="Accept-Language: es-MX,es;q=0.8,en-US;q=0.5,en;q=0.3" \
    --header="Referer: $ANIME_URL" \
    --header="Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
    --header="Origin: $BASE_URL" \
    --header="X-Requested-With: XMLHttpRequest" \
    --header="Sec-GPC: 1" \
    --header="Sec-Fetch-Dest: empty" \
    --header="Sec-Fetch-Mode: cors" \
    --header="Sec-Fetch-Site: same-origin" \
    --header="Pragma: no-cache" \
    --header="Cache-Control: no-cache" \
    --post-data="_token=$CSRF_TOKEN" \
    -O - "$API_CHAPTERS/$ANIME_ID/$CHAPTER_NUM" \
    2>/dev/null | jq .total
