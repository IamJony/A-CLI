#!/bin/bash
# Script: servers_ext.sh
# Autor: IamJony
# Fecha: $(date +%Y-%m-%d)
# Descripcion: Extrae los servidores de video embebidos del sitio web

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SOURCE_DIR/config.sh" || {
    echo "Error: No se encuentra config.sh"
    exit 1
}
