#!/bin/bash
# m3u8.sh - Extrae URL m3u8 de reproductor con multiples metodos
# Uso: ./m3u8.sh <url> [-d|--debug]

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SOURCE_DIR/config.sh" || {
    echo "Error: No se encuentra config.sh"
    exit 1
}

[ -z "$1" ] && { echo "Uso: $0 <url> [-d|--debug]"; exit 1; }

URL="$1"
DEBUG=0

# Verificar si hay parametro de depuracion
for arg in "$@"; do
    case $arg in
        -d|--debug)
        DEBUG=1
        shift
        ;;
    esac
done

TEMP_HTML="$TEMP_DIR/page.html"
TEMP_STREAM="$TEMP_DIR/stream.m3u8"
TEMP_JSON="$TEMP_DIR/stream.json"

# Funcion para depuracion
debug() {
    if [ "$DEBUG" -eq 1 ]; then
        echo "[DEBUG] $1" >&2
    fi
}

# Funcion para echo normal
info() {
    if [ "$DEBUG" -eq 1 ]; then
        echo "[INFO] $1" >&2
    fi
}

# Descargar la pagina
debug "Descargando pagina: $URL"
wget -q --load-cookies="$COOKIE_FILE" --user-agent="$USER_AGENT" \
     -O "$TEMP_HTML" "$URL" 2>/dev/null
debug "Pagina guardada en: $TEMP_HTML"

# METODO 1: Buscar atob() (decodificacion base64 en JS)
debug "Ejecutando Metodo 1: atob()"
M3U8_URL=$(grep -o "atob('[^']*')" "$TEMP_HTML" | \
    head -1 | \
    sed "s/.*atob('\([^']*\)').*/\1/" | \
    base64 -d 2>/dev/null | \
    grep -o "https\?://[^\"']*\.m3u8[^\"']*" | \
    head -1)

if [ -n "$M3U8_URL" ]; then
    debug "Metodo 1 exitoso: $M3U8_URL"
else
    debug "Metodo 1 fallo"
fi

# METODO 2: Buscar variable con m3u8 en JS
if [ -z "$M3U8_URL" ]; then
    info "Metodo 1 fallo, probando metodo 2 (variables JS)..."
    debug "Ejecutando Metodo 2: variables JS"
    M3U8_URL=$(grep -o "var [a-zA-Z0-9_]*\s*=\s*'https\?://[^\"']*\.m3u8[^\"']*'" "$TEMP_HTML" | \
        head -1 | \
        sed "s/.*'\(https\?:\/\/[^\"']*\.m3u8[^\"']*\)'.*/\1/")

    if [ -n "$M3U8_URL" ]; then
        debug "Metodo 2 exitoso: $M3U8_URL"
    else
        debug "Metodo 2 fallo"
    fi
fi

# METODO 3: Buscar URL m3u8 directamente en el HTML
if [ -z "$M3U8_URL" ]; then
    info "Metodo 2 fallo, probando metodo 3 (URLs directas)..."
    debug "Ejecutando Metodo 3: URLs directas"
    M3U8_URL=$(grep -o "https\?://[^\"']*\.m3u8[^\"']*" "$TEMP_HTML" | head -1)

    if [ -n "$M3U8_URL" ]; then
        debug "Metodo 3 exitoso: $M3U8_URL"
    else
        debug "Metodo 3 fallo"
    fi
fi

# METODO 4: Buscar en scripts decodificados con unescape
if [ -z "$M3U8_URL" ]; then
    info "Metodo 3 fallo, probando metodo 4 (unescape)..."
    debug "Ejecutando Metodo 4: unescape()"
    ENCODED=$(grep -o "unescape('[^']*')" "$TEMP_HTML" | head -1 | sed "s/.*unescape('\([^']*\)').*/\1/")
    if [ -n "$ENCODED" ]; then
        debug "Contenido unescape encontrado: $ENCODED"
        M3U8_URL=$(printf "%b" "$ENCODED" | grep -o "https\?://[^\"']*\.m3u8[^\"']*" | head -1)
        if [ -n "$M3U8_URL" ]; then
            debug "Metodo 4 exitoso: $M3U8_URL"
        else
            debug "Metodo 4 fallo - no se encontro URL en unescape"
        fi
    else
        debug "Metodo 4 fallo - no se encontro unescape"
    fi
fi

# METODO 5: Buscar en eval(p,a,c,k,e,d) - Packer
if [ -z "$M3U8_URL" ]; then
    info "Metodo 4 fallo, probando metodo 5 (eval packed)..."
    debug "Ejecutando Metodo 5: eval packed"
    PACKED=$(grep -o "eval(.*)" "$TEMP_HTML" | grep -o "}('.*',[0-9]*,[0-9]*,'[^']*')" | head -1)
    if [ -n "$PACKED" ]; then
        debug "Packed encontrado: ${PACKED:0:100}..."
        M3U8_URL=$(echo "$PACKED" | grep -o "https\?://[^\"']*\.m3u8[^\"']*" | head -1)
        if [ -n "$M3U8_URL" ]; then
            debug "Metodo 5 exitoso: $M3U8_URL"
        else
            debug "Metodo 5 fallo - no se encontro URL en packed"
        fi
    else
        debug "Metodo 5 fallo - no se encontro packed"
    fi
fi

# METODO 6: Buscar en objetos JSON dentro de scripts
if [ -z "$M3U8_URL" ]; then
    info "Metodo 5 fallo, probando metodo 6 (JSON)..."
    debug "Ejecutando Metodo 6: JSON"
    M3U8_URL=$(grep -o "{\"[^\"]*\":\"https\?://[^\"]*\.m3u8[^\"]*\"}" "$TEMP_HTML" | \
        head -1 | \
        grep -o "https\?://[^\"]*\.m3u8[^\"]*")

    if [ -n "$M3U8_URL" ]; then
        debug "Metodo 6 exitoso: $M3U8_URL"
    else
        debug "Metodo 6 fallo"
    fi
fi

# METODO 7: Extraer de iframe y recursion
if [ -z "$M3U8_URL" ]; then
    info "Metodo 6 fallo, probando metodo 7 (iframe)..."
    debug "Ejecutando Metodo 7: iframe"
    IFRAME_URL=$(grep -o '<iframe[^>]*src="[^"]*"' "$TEMP_HTML" | \
        head -1 | \
        sed 's/.*src="\([^"]*\)".*/\1/')

    if [ -n "$IFRAME_URL" ]; then
        debug "Iframe encontrado: $IFRAME_URL"
        if [[ "$IFRAME_URL" != http* ]]; then
            IFRAME_URL="https://cdn.jkdesa.com$IFRAME_URL"
            debug "Iframe normalizado: $IFRAME_URL"
        fi

        if [ "$IFRAME_URL" != "$URL" ]; then
            info "Siguiendo iframe: $IFRAME_URL"
            debug "Llamada recursiva a: $IFRAME_URL"
            M3U8_URL=$($0 "$IFRAME_URL" $( [ "$DEBUG" -eq 1 ] && echo "--debug" ) 2>/dev/null)
            if [ -n "$M3U8_URL" ]; then
                debug "Metodo 7 exitoso (recursion): $M3U8_URL"
            else
                debug "Metodo 7 fallo - no se encontro URL en iframe"
            fi
        else
            debug "Metodo 7 fallo - iframe mismo que URL actual"
        fi
    else
        debug "Metodo 7 fallo - no se encontro iframe"
    fi
fi

# METODO 8: Buscar en comentarios HTML
if [ -z "$M3U8_URL" ]; then
    info "Metodo 7 fallo, probando metodo 8 (comentarios)..."
    debug "Ejecutando Metodo 8: comentarios HTML"
    M3U8_URL=$(grep -o "<!--.*https\?://[^\"']*\.m3u8[^\"']*.*-->" "$TEMP_HTML" | \
        head -1 | \
        grep -o "https\?://[^\"']*\.m3u8[^\"']*")

    if [ -n "$M3U8_URL" ]; then
        debug "Metodo 8 exitoso: $M3U8_URL"
    else
        debug "Metodo 8 fallo"
    fi
fi

# METODO 9: Buscar en decodeURIComponent
if [ -z "$M3U8_URL" ]; then
    info "Metodo 8 fallo, probando metodo 9 (decodeURIComponent)..."
    debug "Ejecutando Metodo 9: decodeURIComponent"
    ENCODED=$(grep -o "decodeURIComponent('[^']*')" "$TEMP_HTML" | \
        head -1 | \
        sed "s/.*decodeURIComponent('\([^']*\)').*/\1/")

    if [ -n "$ENCODED" ]; then
        debug "URI encoded encontrado: $ENCODED"
        DECODED=$(echo "$ENCODED" | python3 -c "import sys, urllib.parse; print(urllib.parse.unquote(sys.stdin.read()))" 2>/dev/null)
        if [ -n "$DECODED" ]; then
            debug "URI decoded: $DECODED"
            M3U8_URL=$(echo "$DECODED" | grep -o "https\?://[^\"']*\.m3u8[^\"']*" | head -1)
            if [ -n "$M3U8_URL" ]; then
                debug "Metodo 9 exitoso: $M3U8_URL"
            else
                debug "Metodo 9 fallo - no se encontro URL en decoded"
            fi
        else
            debug "Metodo 9 fallo - error al decodificar"
        fi
    else
        debug "Metodo 9 fallo - no se encontro decodeURIComponent"
    fi
fi

# METODO 10: Buscar en data-setup de videojs
if [ -z "$M3U8_URL" ]; then
    info "Metodo 9 fallo, probando metodo 10 (videojs)..."
    debug "Ejecutando Metodo 10: videojs data-setup"
    M3U8_URL=$(grep -o 'data-setup="[^"]*\.m3u8[^"]*"' "$TEMP_HTML" | \
        head -1 | \
        grep -o "https\?://[^\"']*\.m3u8[^\"']*")

    if [ -n "$M3U8_URL" ]; then
        debug "Metodo 10 exitoso: $M3U8_URL"
    else
        debug "Metodo 10 fallo"
    fi
fi

# METODO 11: Buscar en configuraciones de reproductor
if [ -z "$M3U8_URL" ]; then
    info "Metodo 10 fallo, probando metodo 11 (player config)..."
    debug "Ejecutando Metodo 11: configuraciones de reproductor"
    M3U8_URL=$(grep -o "file[\"']*:[\"']*[^\"']*\.m3u8[^\"']*[\"']*" "$TEMP_HTML" | \
        head -1 | \
        grep -o "https\?://[^\"']*\.m3u8[^\"']*")

    if [ -n "$M3U8_URL" ]; then
        debug "Metodo 11 exitoso: $M3U8_URL"
    else
        debug "Metodo 11 fallo"
    fi
fi

# Guardar resultado
if [ -n "$M3U8_URL" ]; then
    echo "$M3U8_URL" > "$TEMP_STREAM"
    echo "{\"m3u8\": \"$M3U8_URL\"}" > "$TEMP_JSON"

    if [ "$DEBUG" -eq 1 ]; then
        echo "[OK] URL m3u8 encontrada: $M3U8_URL" >&2
        debug "Archivos generados:"
        debug "  - HTML: $TEMP_HTML"
        debug "  - Stream: $TEMP_STREAM"
        debug "  - JSON: $TEMP_JSON"
    fi

    echo "$M3U8_URL"
else
    echo '{"m3u8": null}' > "$TEMP_JSON"

    if [ "$DEBUG" -eq 1 ]; then
        echo "[ERROR] No se pudo extraer la URL m3u8 por ningun metodo" >&2
        debug "HTML guardado en: $TEMP_HTML para analisis manual"
    else
        echo "[ERROR] No encontrado lista m3u8"
    fi
    exit 1
fi
