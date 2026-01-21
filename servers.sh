#!/bin/bash
# servers.sh - Extrae servidores para ver anime pero depende de que el usuario o la interfaz cli descargue la pagina del capitulo del anime https://xxxxxxx/jujutsu-kaisen-tv/1

# Cargar configuración
source config.sh 2>/dev/null || {
    echo "Error: No se encuentra config.sh"
    exit 1
}

# Extraer servidores - CORREGIDO: Usar la ruta correcta del archivo HTML
SERVERS=$(cat "$TEMP_DIR/anime.html" 2>/dev/null | grep "jkplayer/um" | sed -n 's/.*src="\([^"]*\)".*/\1/p')

if [ -z "$SERVERS" ]; then
    echo "Error: No se encontraron servidores en $TEMP_DIR/anime.html"
    exit 1
fi

# Crear JSON
cat > "$TEMP_DIR/servers.json" << EOF
{
  "servers": [
EOF

# Agregar cada servidor
FIRST=true
echo "$SERVERS" | while read -r SERVER; do
    if [ -n "$SERVER" ]; then
        if [ "$FIRST" = true ]; then
            echo "    \"$SERVER\"" >> "$TEMP_DIR/servers.json"
            FIRST=false
        else
            echo "    ,\"$SERVER\"" >> "$TEMP_DIR/servers.json"
        fi
    fi
done

# Cerrar JSON
cat >> "$TEMP_DIR/servers.json" << EOF
  ]
}
EOF

#echo "servers.json creado"
