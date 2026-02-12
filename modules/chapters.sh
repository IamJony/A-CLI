#!/bin/bash

# Este script regresa el total de capitulos

source ./modules/config.sh 2>/dev/null || {
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

# URL específica para el anime (necesaria para el Referer)
ANIME_URL="$BASE_URL/akuma-no-riddle"  


# Mensajes de depuracion para verificar si esta funcionando
#echo "Obteniendo capítulos para anime ID: $ANIME_ID, capítulo: $CHAPTER_NUM"
#echo "Token CSRF: ${CSRF_TOKEN:0:10}..."
#echo "$API_CHAPTERS/$ANIME_ID/$CHAPTER_NUM"

# Ahora hacer la petición AJAX para obtener los episodios

curl -s "$API_CHAPTERS/$ANIME_ID/$CHAPTER_NUM" \
    -X POST \
    -H "User-Agent: $USER_AGENT" \
    -H "Accept: application/json, text/javascript, */*; q=0.01" \
    -H "Accept-Language: es-MX,es;q=0.8,en-US;q=0.5,en;q=0.3" \
    -H "Accept-Encoding: gzip, deflate, br, zstd" \
    -H "Referer: $ANIME_URL" \
    -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
    -H "Origin: $BASE_URL" \
    -H "Sec-GPC: 1" \
    -H "Connection: keep-alive" \
    -H "Sec-Fetch-Dest: empty" \
    -H "Sec-Fetch-Mode: cors" \
    -H "Sec-Fetch-Site: same-origin" \
    -H "Pragma: no-cache" \
    -H "Cache-Control: no-cache" \
    -H "TE: trailers" \
    -b "$COOKIE_FILE" \
    --compressed \
    --data-raw "_token=$CSRF_TOKEN" | jq .total
