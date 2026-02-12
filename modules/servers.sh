#!/bin/bash
# servers.sh - Extrae servidores para ver anime
# Depende de que el usuario descargue la página del capítulo

# Cargar configuración
source ./modules/config.sh 2>/dev/null || {
    echo "Error: No se encuentra config.sh"
    exit 1
}

# Variables globales
declare -a MAIN_SERVERS
declare -a EMBEDDED_SERVERS
declare -a ALL_SERVERS

# Funciones
verificar_archivo_html() {
    if [ ! -f "$TEMP_DIR/anime.html" ]; then
        echo "Error: No se encuentra $TEMP_DIR/anime.html"
        echo "Por favor, descarga primero la página del capítulo"
        exit 1
    fi
}

extraer_servidores_principales() {
    echo "Extrayendo servidores principales..."
    
    local servidores=$(grep "jkplayer/um" "$TEMP_DIR/anime.html" | sed -n 's/.*src="\([^"]*\)".*/\1/p')
    
    if [ -z "$servidores" ]; then
        echo "⚠️ No se encontraron servidores principales (jkplayer/um)"
        return 1
    fi
    
    while IFS= read -r servidor; do
        if [ -n "$servidor" ]; then
            MAIN_SERVERS+=("$servidor")
        fi
    done <<< "$servidores"
    
    echo "✓ Encontrados ${#MAIN_SERVERS[@]} servidores principales"
    return 0
}

extraer_servidores_embebidos() {
    echo "Extrayendo servidores embebidos (base64)..."
    
    local embedded_raw=$(grep -o '"remote":"[^"]*"' "$TEMP_DIR/anime.html" | sed 's/"remote":"//g;s/"//g')
    
    if [ -z "$embedded_raw" ]; then
        echo "⚠️ No se encontraron servidores embebidos (base64)"
        return 1
    fi
    
    local contador=0
    while IFS= read -r linea; do
        if [ -n "$linea" ]; then
            local decoded=$(echo "$linea" | base64 -d 2>/dev/null)
            if [ -n "$decoded" ] && [ "$decoded" != "null" ]; then
                EMBEDDED_SERVERS+=("$decoded")
                ((contador++))
            fi
        fi
    done <<< "$embedded_raw"
    
    if [ $contador -eq 0 ]; then
        echo "⚠️ No se pudieron decodificar servidores embebidos"
        return 1
    fi
    
    echo "✓ Encontrados $contador servidores embebidos"
    return 0
}

combinar_servidores() {
    # Agregar servidores principales
    for servidor in "${MAIN_SERVERS[@]}"; do
        ALL_SERVERS+=("$servidor")
    done
    
    # Agregar servidores embebidos
    for servidor in "${EMBEDDED_SERVERS[@]}"; do
        ALL_SERVERS+=("$servidor")
    done
    
    if [ ${#ALL_SERVERS[@]} -eq 0 ]; then
        echo "❌ Error: No se encontraron servidores de ningún tipo"
        return 1
    fi
    
    echo "✓ Total combinado: ${#ALL_SERVERS[@]} servidores"
    return 0
}

crear_json() {
    echo "Creando archivo JSON..."
    
    cat > "$TEMP_DIR/servers.json" << EOF
{
  "servers": [
EOF
    
    for ((i=0; i<${#ALL_SERVERS[@]}; i++)); do
        local servidor="${ALL_SERVERS[$i]}"
        # Escapar caracteres especiales para JSON
        local servidor_escaped=$(echo "$servidor" | sed 's/"/\\"/g;s/\\/\\\\/g')
        
        if [ $i -eq 0 ]; then
            echo "    \"$servidor_escaped\"" >> "$TEMP_DIR/servers.json"
        else
            echo "    ,\"$servidor_escaped\"" >> "$TEMP_DIR/servers.json"
        fi
    done
    
    cat >> "$TEMP_DIR/servers.json" << EOF
  ],
  "metadata": {
    "total_servers": ${#ALL_SERVERS[@]},
    "main_servers": ${#MAIN_SERVERS[@]},
    "embedded_servers": ${#EMBEDDED_SERVERS[@]},
    "extracted_at": "$(date -Iseconds)"
  }
}
EOF
    
    echo "✓ Archivo JSON creado: $TEMP_DIR/servers.json"
}



# Programa principal
main() {
    echo "══════════════════════════════════════════════════════════"
    echo "            EXTRACCIÓN DE SERVIDORES DE ANIME"
    echo "══════════════════════════════════════════════════════════"
    
    # Paso 1: Verificar archivo HTML
    verificar_archivo_html
    
    # Paso 2: Extraer servidores principales
    if ! extraer_servidores_principales; then
        echo "➡️ Continuando sin servidores principales..."
    fi
    
    # Paso 3: Extraer servidores embebidos
    if ! extraer_servidores_embebidos; then
        echo "➡️ Continuando sin servidores embebidos..."
    fi
    
    # Paso 4: Combinar servidores
    if ! combinar_servidores; then
        exit 1
    fi
    
    # Paso 5: Crear JSON
    crear_json
    
    # Paso 6: Mostrar resumen
 
}

# Ejecutar programa principal
main
