#!/bin/bash
# m3u8.sh - Extrae URL m3u8 de reproductor con múltiples métodos
# Uso: ./get_m3u8.sh <url> [-d|--debug]

source ./modules/config.sh 2>/dev/null || {
    echo "Error: No config.sh"
    exit 1
}

[ -z "$1" ] && { echo "Uso: $0 <url> [-d|--debug]"; exit 1; }

URL="$1"
DEBUG=0

# Verificar si hay parámetro de depuración
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

# Función para depuración
debug() {
    if [ "$DEBUG" -eq 1 ]; then
        echo "[DEBUG] $1" >&2
    fi
}

# Función para echo normal
info() {
    if [ "$DEBUG" -eq 1 ]; then
        echo "🔍 $1" >&2
    fi
}

# Descargar la página
debug "Descargando página: $URL"
curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" "$URL" > "$TEMP_HTML"
debug "Página guardada en: $TEMP_HTML"

# MÉTODO 1: Buscar atob() (decodificación base64 en JS)
debug "Ejecutando Método 1: atob()"
M3U8_URL=$(grep -o "atob('[^']*')" "$TEMP_HTML" | \
    head -1 | \
    sed "s/.*atob('\([^']*\)').*/\1/" | \
    base64 -d 2>/dev/null | \
    grep -o "https\\?://[^\"']*\\.m3u8[^\"']*" | \
    head -1)

if [ -n "$M3U8_URL" ]; then
    debug "Método 1 exitoso: $M3U8_URL"
else
    debug "Método 1 falló"
fi

# MÉTODO 2: Buscar variable con m3u8 en JS
if [ -z "$M3U8_URL" ]; then
    info "Método 1 falló, probando método 2 (variables JS)..."
    debug "Ejecutando Método 2: variables JS"
    M3U8_URL=$(grep -o "var [a-zA-Z0-9_]*\\s*=\\s*'https\\?://[^\"']*\\.m3u8[^\"']*'" "$TEMP_HTML" | \
        head -1 | \
        sed "s/.*'\(https\\?:\/\/[^\"']*\.m3u8[^\"']*\)'.*/\1/")
    
    if [ -n "$M3U8_URL" ]; then
        debug "Método 2 exitoso: $M3U8_URL"
    else
        debug "Método 2 falló"
    fi
fi

# MÉTODO 3: Buscar URL m3u8 directamente en el HTML
if [ -z "$M3U8_URL" ]; then
    info "Método 2 falló, probando método 3 (URLs directas)..."
    debug "Ejecutando Método 3: URLs directas"
    M3U8_URL=$(grep -o "https\\?://[^\"']*\\.m3u8[^\"']*" "$TEMP_HTML" | head -1)
    
    if [ -n "$M3U8_URL" ]; then
        debug "Método 3 exitoso: $M3U8_URL"
    else
        debug "Método 3 falló"
    fi
fi

# MÉTODO 4: Buscar en scripts decodificados con unescape
if [ -z "$M3U8_URL" ]; then
    info "Método 3 falló, probando método 4 (unescape)..."
    debug "Ejecutando Método 4: unescape()"
    ENCODED=$(grep -o "unescape('[^']*')" "$TEMP_HTML" | head -1 | sed "s/.*unescape('\([^']*\)').*/\1/")
    if [ -n "$ENCODED" ]; then
        debug "Contenido unescape encontrado: $ENCODED"
        M3U8_URL=$(printf "%b" "$ENCODED" | grep -o "https\\?://[^\"']*\\.m3u8[^\"']*" | head -1)
        if [ -n "$M3U8_URL" ]; then
            debug "Método 4 exitoso: $M3U8_URL"
        else
            debug "Método 4 falló - no se encontró URL en unescape"
        fi
    else
        debug "Método 4 falló - no se encontró unescape"
    fi
fi

# MÉTODO 5: Buscar en eval(p,a,c,k,e,d) - Packer
if [ -z "$M3U8_URL" ]; then
    info "Método 4 falló, probando método 5 (eval packed)..."
    debug "Ejecutando Método 5: eval packed"
    PACKED=$(grep -o "eval(.*)" "$TEMP_HTML" | grep -o "}('.*',[0-9]*,[0-9]*,'[^']*')" | head -1)
    if [ -n "$PACKED" ]; then
        debug "Packed encontrado: ${PACKED:0:100}..."
        M3U8_URL=$(echo "$PACKED" | grep -o "https\\?://[^\"']*\\.m3u8[^\"']*" | head -1)
        if [ -n "$M3U8_URL" ]; then
            debug "Método 5 exitoso: $M3U8_URL"
        else
            debug "Método 5 falló - no se encontró URL en packed"
        fi
    else
        debug "Método 5 falló - no se encontró packed"
    fi
fi

# MÉTODO 6: Buscar en objetos JSON dentro de scripts
if [ -z "$M3U8_URL" ]; then
    info "Método 5 falló, probando método 6 (JSON)..."
    debug "Ejecutando Método 6: JSON"
    M3U8_URL=$(grep -o "{\"[^\"]*\":\"https\\?://[^\"]*\.m3u8[^\"]*\"}" "$TEMP_HTML" | \
        head -1 | \
        grep -o "https\\?://[^\"]*\.m3u8[^\"]*")
    
    if [ -n "$M3U8_URL" ]; then
        debug "Método 6 exitoso: $M3U8_URL"
    else
        debug "Método 6 falló"
    fi
fi

# MÉTODO 7: Extraer de iframe y recursión
if [ -z "$M3U8_URL" ]; then
    info "Método 6 falló, probando método 7 (iframe)..."
    debug "Ejecutando Método 7: iframe"
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
                debug "Método 7 exitoso (recursión): $M3U8_URL"
            else
                debug "Método 7 falló - no se encontró URL en iframe"
            fi
        else
            debug "Método 7 falló - iframe mismo que URL actual"
        fi
    else
        debug "Método 7 falló - no se encontró iframe"
    fi
fi

# MÉTODO 8: Buscar en comentarios HTML
if [ -z "$M3U8_URL" ]; then
    info "Método 7 falló, probando método 8 (comentarios)..."
    debug "Ejecutando Método 8: comentarios HTML"
    M3U8_URL=$(grep -o "<!--.*https\\?://[^\"']*\\.m3u8[^\"']*.*-->" "$TEMP_HTML" | \
        head -1 | \
        grep -o "https\\?://[^\"']*\\.m3u8[^\"']*")
    
    if [ -n "$M3U8_URL" ]; then
        debug "Método 8 exitoso: $M3U8_URL"
    else
        debug "Método 8 falló"
    fi
fi

# MÉTODO 9: Buscar en decodeURIComponent
if [ -z "$M3U8_URL" ]; then
    info "Método 8 falló, probando método 9 (decodeURIComponent)..."
    debug "Ejecutando Método 9: decodeURIComponent"
    ENCODED=$(grep -o "decodeURIComponent('[^']*')" "$TEMP_HTML" | \
        head -1 | \
        sed "s/.*decodeURIComponent('\([^']*\)').*/\1/")
    
    if [ -n "$ENCODED" ]; then
        debug "URI encoded encontrado: $ENCODED"
        DECODED=$(echo "$ENCODED" | python3 -c "import sys, urllib.parse; print(urllib.parse.unquote(sys.stdin.read()))" 2>/dev/null)
        if [ -n "$DECODED" ]; then
            debug "URI decoded: $DECODED"
            M3U8_URL=$(echo "$DECODED" | grep -o "https\\?://[^\"']*\\.m3u8[^\"']*" | head -1)
            if [ -n "$M3U8_URL" ]; then
                debug "Método 9 exitoso: $M3U8_URL"
            else
                debug "Método 9 falló - no se encontró URL en decoded"
            fi
        else
            debug "Método 9 falló - error al decodificar"
        fi
    else
        debug "Método 9 falló - no se encontró decodeURIComponent"
    fi
fi

# MÉTODO 10: Buscar en data-setup de videojs
if [ -z "$M3U8_URL" ]; then
    info "Método 9 falló, probando método 10 (videojs)..."
    debug "Ejecutando Método 10: videojs data-setup"
    M3U8_URL=$(grep -o 'data-setup="[^"]*\.m3u8[^"]*"' "$TEMP_HTML" | \
        head -1 | \
        grep -o "https\\?://[^\"']*\\.m3u8[^\"']*")
    
    if [ -n "$M3U8_URL" ]; then
        debug "Método 10 exitoso: $M3U8_URL"
    else
        debug "Método 10 falló"
    fi
fi

# MÉTODO 11: Buscar en configuraciones de reproductor
if [ -z "$M3U8_URL" ]; then
    info "Método 10 falló, probando método 11 (player config)..."
    debug "Ejecutando Método 11: configuraciones de reproductor"
    M3U8_URL=$(grep -o "file[\"']*:[\"']*[^\"']*\.m3u8[^\"']*[\"']*" "$TEMP_HTML" | \
        head -1 | \
        grep -o "https\\?://[^\"']*\\.m3u8[^\"']*")
    
    if [ -n "$M3U8_URL" ]; then
        debug "Método 11 exitoso: $M3U8_URL"
    else
        debug "Método 11 falló"
    fi
fi

# Guardar resultado
if [ -n "$M3U8_URL" ]; then
    echo "$M3U8_URL" > "$TEMP_STREAM"
    echo "{\"m3u8\": \"$M3U8_URL\"}" > "$TEMP_JSON"
    
    if [ "$DEBUG" -eq 1 ]; then
        echo "✅ URL m3u8 encontrada: $M3U8_URL" >&2
        debug "Archivos generados:"
        debug "  - HTML: $TEMP_HTML"
        debug "  - Stream: $TEMP_STREAM"
        debug "  - JSON: $TEMP_JSON"
    fi
    
    echo "$M3U8_URL"
else
    echo '{"m3u8": null}' > "$TEMP_JSON"
    
    if [ "$DEBUG" -eq 1 ]; then
        echo "❌ No se pudo extraer la URL m3u8 por ningún método" >&2
        debug "HTML guardado en: $TEMP_HTML para análisis manual"
    else
        echo "❌ No encontrado lista m3u8"
    fi
    exit 1
fi
