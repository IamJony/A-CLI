#!/bin/bash
# A-CLI.sh - Interfaz CLI para A-CLI by IamJony

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$BASE_DIR/modules/config.sh" ]; then
    echo -e "${RED}Error: No se encuentra $BASE_DIR/modules/config.sh${NC}"
    exit 1
fi
source "$BASE_DIR/modules/config.sh"

mkdir -p "$TEMP_DIR"

menu_principal() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║             ${YELLOW}A-CLI v1.0${CYAN}                 ║${NC}"
    echo -e "${CYAN}║    ${BLUE}https://github.com/IamJony${CYAN}   ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}[1] Buscar anime${NC}"
    echo -e "${GREEN}[2] Reproducir desde URL${NC}"
    echo -e "${GREEN}[3] Salir${NC}"
    echo -e "${GREEN}[4] Eliminar Archivos Temporales${NC}"
    echo ""
    echo -n "Selecciona: "
}

buscar_anime() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}BUSCAR ANIME${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -n "Nombre del anime: "
    read nombre

    if [ -z "$nombre" ]; then
        echo -e "${RED}No ingresaste nada${NC}"
        sleep 2
        return 1
    fi

    echo -e "${GREEN}Buscando...${NC}"

    "$BASE_DIR/modules/search.sh" "$nombre"

    if [ ! -f "$TEMP_DIR/search.json" ] || [ ! -s "$TEMP_DIR/search.json" ]; then
        echo -e "${RED}No se encontraron resultados${NC}"
        sleep 2
        return 1
    fi

    echo ""
    echo -e "${YELLOW}Resultados encontrados:${NC}"
    echo "════════════════════════════════════"

    if command -v jq &> /dev/null; then
        total_resultados=$(jq '. | length' "$TEMP_DIR/search.json")
        jq -r 'to_entries[] | "\(.key+1). \(.value.title)"' "$TEMP_DIR/search.json"
    else
        total_resultados=$(grep -c '"title":' "$TEMP_DIR/search.json")
        grep '"title":' "$TEMP_DIR/search.json" | sed 's/.*"title": "//;s/".*//' | cat -n
    fi

    echo "════════════════════════════════════"
    echo -e "${GREEN}Total: $total_resultados resultados${NC}"
    echo ""

    echo -n "Selecciona un anime (0 para cancelar): "
    read seleccion

    if [ "$seleccion" = "0" ] || [ -z "$seleccion" ]; then
        return 1
    fi

    if [ "$seleccion" -lt 1 ] || [ "$seleccion" -gt "$total_resultados" ]; then
        echo -e "${RED}Seleccion invalida${NC}"
        sleep 2
        return 1
    fi

    if command -v jq &> /dev/null; then
        anime_id=$(jq -r ".[$(($seleccion-1))].id" "$TEMP_DIR/search.json")
        anime_title=$(jq -r ".[$(($seleccion-1))].title" "$TEMP_DIR/search.json")
        anime_slug=$(jq -r ".[$(($seleccion-1))].slug" "$TEMP_DIR/search.json")
    else
        anime_info=$(grep -A5 -B5 "\"id\":" "$TEMP_DIR/search.json" | head -20)
        anime_id=$(echo "$anime_info" | grep '"id"' | sed -n "${seleccion}p" | sed 's/.*"id": "//;s/".*//')
        anime_title=$(echo "$anime_info" | grep '"title"' | sed -n "${seleccion}p" | sed 's/.*"title": "//;s/".*//')
        anime_slug=$(echo "$anime_info" | grep '"slug"' | sed -n "${seleccion}p" | sed 's/.*"slug": "//;s/".*//')
    fi

    if [ -z "$anime_slug" ]; then
        echo -e "${RED}Error al obtener información del anime${NC}"
        sleep 2
        return 1
    fi

    echo -e "${GREEN}Seleccionado: $anime_title${NC}"
    echo -e "${GREEN}ID: $anime_id${NC}"

    echo ""
    echo -e "${YELLOW}Consultando capítulos disponibles...${NC}"

    total_capitulos=$("$BASE_DIR/modules/chapters.sh" "$anime_id" 1)

    if [ $? -ne 0 ] || [ -z "$total_capitulos" ]; then
        echo -e "${RED}Error al obtener capítulos${NC}"
        sleep 2
        return 1
    fi

    echo ""
    echo -e "${GREEN}Total de capítulos encontrados: $total_capitulos${NC}"

    seleccionar_capitulo "$anime_slug" "$anime_title" "$total_capitulos"
}

seleccionar_capitulo() {
    local slug="$1"
    local titulo="$2"
    local total_capitulos="$3"

    while true; do
        clear
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}SELECCIONAR CAPÍTULO${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${GREEN}Anime: $titulo${NC}"
        echo -e "${GREEN}Total de capítulos: $total_capitulos${NC}"
        echo ""
        echo "──────────────────────────────────"
        echo -e "${YELLOW}Opciones:${NC}"
        echo "  0. Volver al menú principal"
        echo "  00. Buscar otro anime"
        echo "  número. Reproducir capítulo específico"
        echo ""
        echo -n "¿Qué capítulo quieres ver? (1-$total_capitulos): "
        read capitulo

        case "$capitulo" in
            0)
                return 0
                ;;
            00)
                return 1
                ;;
            "")
                echo -e "${RED}No ingresaste nada${NC}"
                sleep 1
                continue
                ;;
            *[!0-9]*)
                echo -e "${RED}Ingresa solo números${NC}"
                sleep 1
                continue
                ;;
            *)
                if [ "$capitulo" -lt 1 ] || [ "$capitulo" -gt "$total_capitulos" ]; then
                    echo -e "${RED}Capitulo invalido (rango: 1-$total_capitulos)${NC}"
                    sleep 1
                    continue
                fi

                echo ""
                echo -n "¿Quieres reproducir automaticamente? (s/n): "
                read autoplay

                if [[ "$autoplay" =~ ^[Ss]$ ]]; then
                    echo -e "${GREEN}✓ Se reproducirá automaticamente con mpv${NC}"
                    reproducir_anime "$slug" "$titulo" "$capitulo"
                else
                    echo -e "${YELLOW}✓ No se reproducirá automaticamente${NC}"
                    url="$BASE_URL/$slug/$capitulo/"
                    curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" "$url" > "$TEMP_DIR/anime.html"

                    if [ $? -ne 0 ]; then
                        echo -e "${RED}Error al descargar la página${NC}"
                        return 1
                    fi

                    echo -e "${YELLOW}Extrayendo servidores...${NC}"
                    "$BASE_DIR/modules/servers.sh"

                    echo ""
                    echo "Puedes consultar los servidores manualmente:"
                    echo -e "${CYAN}cat $TEMP_DIR/servers.json | jq .${NC}"
                    echo ""
                fi

                echo ""
                echo -n "¿Ver otro capítulo de $titulo? (s/n): "
                read respuesta
                if [[ ! "$respuesta" =~ ^[Ss]$ ]]; then
                    return 0
                fi
                ;;
        esac
    done
}

eliminarTemporales() {
    rm -rf "$TEMP_DIR" 2>/dev/null
    mkdir -p "$TEMP_DIR"

    echo -e "${YELLOW}Archivos Temporales Eliminados${NC}"
    sleep 1
}

play_with_mpv() {
    local titulo="$1"
    local capitulo="$2"
    local m3u8_url="$3"

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}INICIANDO REPRODUCCION${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}Reproduciendo: $titulo - Capítulo $capitulo${NC}"
    echo -e "${YELLOW}Controles MPV:${NC}"
    echo -e "${YELLOW}   q = Salir | f = Pantalla completa${NC}"
    echo -e "${YELLOW}   ← → = Navegar 10 segundos${NC}"
    echo -e "${YELLOW}   ↑ ↓ = Volumen${NC}"
    echo -e "${BLUE}──────────────────────────────────${NC}"

    sleep 1

    if command -v mpv &> /dev/null; then
        mpv --referrer="$BASE_URL" \
            --user-agent="$USER_AGENT" \
            --force-media-title="$titulo - Capítulo $capitulo" \
            --no-osc \
            --volume=70 \
            "$m3u8_url"
    else
        echo -e "${RED}MPV no está instalado${NC}"
        echo ""
        echo -e "${YELLOW}Instala MPV:${NC}"
        echo "  Debian/Ubuntu: sudo apt install mpv"
        echo "  Arch: sudo pacman -S mpv"
        echo ""
        echo -e "${YELLOW}URL para reproducir manualmente:${NC}"
        echo "mpv --referrer=\"$BASE_URL\" \"$m3u8_url\""
    fi
}

play_with_mplayer() {
    local titulo="$1"
    local capitulo="$2"
    local m3u8_url="$3"

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}INICIANDO REPRODUCCION${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}Reproduciendo: $titulo - Capítulo $capitulo${NC}"

    sleep 1

    if command -v mplayer &> /dev/null; then
        echo ""
        printf "${YELLOW}▶ Reproduciendo con mplayer (via yt-dlp)...${NC}\n"

        yt-dlp --add-header "Referer: $BASE_URL" \
        -S "res:480" -o - "$m3u8_url" \
        2>${TEMP_DIR}/ytdlp.log \
        | mplayer -zoom -vf scale=640:480 -cache 4096 -demuxer lavf \
		-title "${titulo} - Capitulo ${capitulo}" - \
        >${TEMP_DIR}/mplayer.log 2>&1
    else
        echo -e "${RED}MPlayer no está instalado${NC}"
        echo ""
        echo -e "${YELLOW}URL para reproducir manualmente:${NC}"
        echo "mplayer -zoom -cache 4096 -demuxer lavf -title \"${titulo} - Capitulo ${capitulo}\" -"
    fi
}

reproducir_anime() {
    local slug="$1"
    local titulo="$2"
    local capitulo="$3"

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}PREPARANDO REPRODUCCION${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}Anime: $titulo${NC}"
    echo -e "${GREEN}Capitulo: $capitulo${NC}"

    url="$BASE_URL/$slug/$capitulo/"

    echo -e "${YELLOW}Descargando página...${NC}"
    curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" "$url" > "$TEMP_DIR/anime.html"

    if [ $? -ne 0 ]; then
        echo -e "${RED}Error al descargar la página${NC}"
        return 1
    fi

    echo -e "${YELLOW}Extrayendo servidores...${NC}"
    "$BASE_DIR/modules/servers.sh"

    if [ $? -ne 0 ] || [ ! -f "$TEMP_DIR/servers.json" ]; then
        echo -e "${RED}Error al extraer servidores${NC}"
        return 1
    fi

    if command -v jq &> /dev/null; then
        primer_servidor=$(jq -r '.servers[0]' "$TEMP_DIR/servers.json")
    else
        primer_servidor=$(grep '"' "$TEMP_DIR/servers.json" | head -1 | sed 's/[",]//g')
    fi

    echo ""
    echo -e "${YELLOW}Extrayendo video M3U8...${NC}"
    "$BASE_DIR/modules/m3u8.sh" "$primer_servidor"

    if [ $? -ne 0 ] || [ ! -f "$TEMP_DIR/stream.m3u8" ] || [ ! -s "$TEMP_DIR/stream.m3u8" ]; then
        echo -e "${RED}Error al extraer video M3U8${NC}"
        return 1
    fi

    m3u8_url=$(head -1 "$TEMP_DIR/stream.m3u8")
    echo -e "${GREEN}URL M3U8 obtenida${NC}"

    echo ""
    echo -e "${YELLOW}Selecciona reproductor:${NC}"
    echo "  1. MPlayer (480p)"
    echo "  2. MPV (best)"
    echo -n "Opcion: "
    read reproductor

    case $reproductor in
        1)
            play_with_mplayer "$titulo" "$capitulo" "$m3u8_url"
            ;;
        2)
            play_with_mpv "$titulo" "$capitulo" "$m3u8_url"
            ;;
        *)
            echo -e "${RED}Opcion invalida, usando MPV por defecto${NC}"
            play_with_mpv "$titulo" "$capitulo" "$m3u8_url"
            ;;
    esac

    return 0
}

echo -e "${GREEN}Iniciando Anime CLI...${NC}"
echo -e "${YELLOW}Cargando configuración...${NC}"

while true; do
    menu_principal
    read opcion

    case $opcion in
        1)
            buscar_anime
            ;;
        2)
            echo -e "${YELLOW}Opcion disponible para futuras versiones :("
            ;;
        3)
            echo ""
            echo -e "${GREEN}¡Hasta luego!${NC}"
            echo ""
            exit 0
            ;;
        4)
            eliminarTemporales
            ;;
        *)
            echo -e "${RED}Opcion invalida${NC}"
            sleep 1
            ;;
    esac

    echo ""
    echo -n "Presiona Enter para continuar al menú principal..."
    read
done
