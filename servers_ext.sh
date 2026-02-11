#!/bin/bash
# Script: servers_ext.sh
# Autor: IamJony
# Fecha: $(date +%Y-%m-%d)
# Descripcion: Extrae los servidores de video embebidos del sitio web

if [ ! -f "config.sh" ]; then
    echo -e "${RED}Error: No se encuentra config.sh${NC}"
    exit 1
fi

source config.sh
