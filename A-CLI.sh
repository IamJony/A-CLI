#!/bin/bash
# A-CLI.sh - Interfaz CLI para A-CLI by IamJony

export LANG=C
export LC_ALL=C

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$BASE_DIR/modules/config.sh" ]; then
    printf '%b\n' "${RED}Error: No se encuentra $BASE_DIR/modules/config.sh${NC}"
    exit 1
fi
source "$BASE_DIR/modules/config.sh"

mkdir -p "$TEMP_DIR"

# Helper: imprime una linea horizontal ASCII
hr() {
    printf '%s\n' "----------------------------------------"
}

menu_principal() {
    clear
    printf '%b\n' "${CYAN}+----------------------------------------+${NC}"
    printf '%b\n' "${CYAN}|             ${YELLOW}A-CLI v1.0${CYAN}                 |${NC}"
    printf '%b\n' "${CYAN}|    ${BLUE}https://github.com/IamJony${CYAN}       |${NC}"
    printf '%b\n' "${CYAN}+----------------------------------------+${NC}"
    echo ""
    printf '%b\n' "${GREEN}[1] Buscar anime${NC}"
    printf '%b\n' "${GREEN}[2] Reproducir desde URL${NC}"
    printf '%b\n' "${GREEN}[3] Salir${NC}"
    printf '%b\n' "${GREEN}[4] Eliminar archivos temporales${NC}"
    echo ""
    printf '%s' "Selecciona: "
}

buscar_anime() {
    echo ""
    hr
    printf '%b\n' "${YELLOW}BUSCAR ANIME${NC}"
    hr
    echo ""
    printf '%s' "Nombre del anime: "
    read nombre

    if [ -z "$nombre" ]; then
        printf '%b\n' "${RED}No ingresaste nada${NC}"
        sleep 2
        return 1
    fi

    printf '%b\n' "${GREEN}Buscando...${NC}"

    "$BASE_DIR/modules/search.sh" "$nombre"

    if [ ! -f "$TEMP_DIR/search.json" ] || [ ! -s "$TEMP_DIR/search.json" ]; then
        printf '%b\n' "${RED}No se encontraron resultados${NC}"
        sleep 2
        return 1
    fi

    echo ""
    printf '%b\n' "${YELLOW}Resultados encontrados:${NC}"
    printf '%s\n' "========================================"

    if command -v jq &> /dev/null; then
        total_resultados=$(jq '. | length' "$TEMP_DIR/search.json")
        jq -r 'to_entries[] | "\(.key+1). \(.value.title)"' "$TEMP_DIR/search.json"
    else
        total_resultados=$(grep -c '"title":' "$TEMP_DIR/search.json")
        grep '"title":' "$TEMP_DIR/search.json" | sed 's/.*"title": "//;s/".*//' | cat -n
    fi

    printf '%s\n' "========================================"
    printf '%b\n' "${GREEN}Total: $total_resultados resultados${NC}"
    echo ""

    printf '%s' "Selecciona un anime (0 para cancelar): "
    read seleccion

    if [ "$seleccion" = "0" ] || [ -z "$seleccion" ]; then
        return 1
    fi

    if [ "$seleccion" -lt 1 ] || [ "$seleccion" -gt "$total_resultados" ]; then
        printf '%b\n' "${RED}Seleccion invalida${NC}"
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
        printf '%b\n' "${RED}Error al obtener informacion del anime${NC}"
        sleep 2
        return 1
    fi

    printf '%b\n' "${GREEN}Seleccionado: $anime_title${NC}"
    printf '%b\n' "${GREEN}ID: $anime_id${NC}"

    echo ""
    printf '%b\n' "${YELLOW}Consultando capitulos disponibles...${NC}"

    total_capitulos=$("$BASE_DIR/modules/chapters.sh" "$anime_id" 1)

    if [ $? -ne 0 ] || [ -z "$total_capitulos" ]; then
        printf '%b\n' "${RED}Error al obtener capitulos${NC}"
        sleep 2
        return 1
    fi

    echo ""
    printf '%b\n' "${GREEN}Total de capitulos encontrados: $total_capitulos${NC}"

    seleccionar_capitulo "$anime_slug" "$anime_title" "$total_capitulos"
}

seleccionar_capitulo() {
    local slug="$1"
    local titulo="$2"
    local total_capitulos="$3"

    while true; do
        clear
        hr
        printf '%b\n' "${YELLOW}SELECCIONAR CAPITULO${NC}"
        hr
        echo ""
        printf '%b\n' "${GREEN}Anime: $titulo${NC}"
        printf '%b\n' "${GREEN}Total de capitulos: $total_capitulos${NC}"
        echo ""
        printf '%s\n' "--------------------------------------"
        printf '%b\n' "${YELLOW}Opciones:${NC}"
        echo "  0. Volver al menu principal"
        echo "  00. Buscar otro anime"
        echo "  numero. Reproducir capitulo especifico"
        echo ""
        printf '%s' "Que capitulo quieres ver? (1-$total_capitulos): "
        read capitulo

        case "$capitulo" in
            0)
                return 0
                ;;
            00)
                return 1
                ;;
            "")
                printf '%b\n' "${RED}No ingresaste nada${NC}"
                sleep 1
                continue
                ;;
            *[!0-9]*)
                printf '%b\n' "${RED}Ingresa solo numeros${NC}"
                sleep 1
                continue
                ;;
            *)
                if [ "$capitulo" -lt 1 ] || [ "$capitulo" -gt "$total_capitulos" ]; then
                    printf '%b\n' "${RED}Capitulo invalido (rango: 1-$total_capitulos)${NC}"
                    sleep 1
                    continue
                fi

                echo ""
                printf '%s' "Quieres reproducir automaticamente? (s/n): "
                read autoplay

                if [[ "$autoplay" =~ ^[Ss]$ ]]; then
                    printf '%b\n' "${GREEN}[OK] Se reproducira automaticamente con mpv${NC}"
                    reproducir_anime "$slug" "$titulo" "$capitulo"
                else
                    printf '%b\n' "${YELLOW}[OK] No se reproducira automaticamente${NC}"
                    url="$BASE_URL/$slug/$capitulo/"
                    wget -q --load-cookies="$COOKIE_FILE" --user-agent="$USER_AGENT" \
                         -O "$TEMP_DIR/anime.html" "$url" 2>/dev/null

                    if [ $? -ne 0 ]; then
                        printf '%b\n' "${RED}Error al descargar la pagina${NC}"
                        return 1
                    fi

                    printf '%b\n' "${YELLOW}Extrayendo servidores...${NC}"
                    "$BASE_DIR/modules/servers.sh"

                    echo ""
                    echo "Puedes consultar los servidores manualmente:"
                    printf '%b\n' "${CYAN}cat $TEMP_DIR/servers.json | jq .${NC}"
                    echo ""
                fi

                echo ""
                printf '%s' "Ver otro capitulo de $titulo? (s/n): "
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

    printf '%b\n' "${YELLOW}Archivos temporales eliminados${NC}"
    sleep 1
}

play_with_mpv() {
    local titulo="$1"
    local capitulo="$2"
    local m3u8_url="$3"

    echo ""
    hr
    printf '%b\n' "${YELLOW}INICIANDO REPRODUCCION${NC}"
    hr
    echo ""
    printf '%b\n' "${GREEN}Reproduciendo: $titulo - Capitulo $capitulo${NC}"
    printf '%b\n' "${YELLOW}Controles MPV:${NC}"
    printf '%b\n' "${YELLOW}   q = Salir | f = Pantalla completa${NC}"
    printf '%b\n' "${YELLOW}   <- -> = Navegar 10 segundos${NC}"
    printf '%b\n' "${YELLOW}   ^  v  = Volumen${NC}"
    printf '%s\n' "----------------------------------"

    sleep 1

    if command -v mpv &> /dev/null; then
        mpv --referrer="$BASE_URL" \
            --user-agent="$USER_AGENT" \
            --force-media-title="$titulo - Capitulo $capitulo" \
            --no-osc \
            --volume=70 \
            "$m3u8_url"
    else
        printf '%b\n' "${RED}MPV no esta instalado${NC}"
        echo ""
        printf '%b\n' "${YELLOW}Instala MPV:${NC}"
        echo "  Debian/Ubuntu: sudo apt install mpv"
        echo "  Arch: sudo pacman -S mpv"
        echo "  Tiny Core: tce-load -wi mpv"
        echo ""
        printf '%b\n' "${YELLOW}URL para reproducir manualmente:${NC}"
        echo "mpv --referrer=\"$BASE_URL\" \"$m3u8_url\""
    fi
}

play_with_mplayer() {
    local titulo="$1"
    local capitulo="$2"
    local m3u8_url="$3"

    echo ""
    hr
    printf '%b\n' "${YELLOW}INICIANDO REPRODUCCION${NC}"
    hr
    echo ""
    printf '%b\n' "${GREEN}Reproduciendo: $titulo - Capitulo $capitulo${NC}"

    sleep 1

    if command -v mplayer &> /dev/null; then
        echo ""
        printf '%b\n' "${YELLOW}> Reproduciendo con mplayer (via yt-dlp)...${NC}"

        yt-dlp --add-header "Referer: $BASE_URL" \
        -S "res:480" -o - "$m3u8_url" \
        2>${TEMP_DIR}/ytdlp.log \
        | mplayer -zoom -vf scale=640:480 -cache 6144 -demuxer lavf \
        -title "${titulo} - Capitulo ${capitulo}" - \
        >${TEMP_DIR}/mplayer.log 2>&1
    else
        printf '%b\n' "${RED}MPlayer no esta instalado${NC}"
        echo ""
        printf '%b\n' "${YELLOW}URL para reproducir manualmente:${NC}"
        echo "mplayer -zoom -cache 4096 -demuxer lavf -title \"${titulo} - Capitulo ${capitulo}\" -"
    fi
}

reproducir_anime() {
    local slug="$1"
    local titulo="$2"
    local capitulo="$3"

    echo ""
    hr
    printf '%b\n' "${YELLOW}PREPARANDO REPRODUCCION${NC}"
    hr
    echo ""
    printf '%b\n' "${GREEN}Anime: $titulo${NC}"
    printf '%b\n' "${GREEN}Capitulo: $capitulo${NC}"

    url="$BASE_URL/$slug/$capitulo/"

    printf '%b\n' "${YELLOW}Descargando pagina...${NC}"
    wget -q --load-cookies="$COOKIE_FILE" --user-agent="$USER_AGENT" \
         -O "$TEMP_DIR/anime.html" "$url" 2>/dev/null

    if [ $? -ne 0 ]; then
        printf '%b\n' "${RED}Error al descargar la pagina${NC}"
        return 1
    fi

    printf '%b\n' "${YELLOW}Extrayendo servidores...${NC}"
    "$BASE_DIR/modules/servers.sh"

    if [ $? -ne 0 ] || [ ! -f "$TEMP_DIR/servers.json" ]; then
        printf '%b\n' "${RED}Error al extraer servidores${NC}"
        return 1
    fi

    if command -v jq &> /dev/null; then
        primer_servidor=$(jq -r '.servers[0]' "$TEMP_DIR/servers.json")
    else
        primer_servidor=$(grep '"' "$TEMP_DIR/servers.json" | head -1 | sed 's/[",]//g')
    fi

    echo ""
    printf '%b\n' "${YELLOW}Extrayendo video M3U8...${NC}"
    "$BASE_DIR/modules/m3u8.sh" "$primer_servidor"

    if [ $? -ne 0 ] || [ ! -f "$TEMP_DIR/stream.m3u8" ] || [ ! -s "$TEMP_DIR/stream.m3u8" ]; then
        printf '%b\n' "${RED}Error al extraer video M3U8${NC}"
        return 1
    fi

    m3u8_url=$(head -1 "$TEMP_DIR/stream.m3u8")
    printf '%b\n' "${GREEN}URL M3U8 obtenida${NC}"

    echo ""
    printf '%b\n' "${YELLOW}Selecciona reproductor:${NC}"
    echo "  1. MPlayer (480p)"
    echo "  2. MPV (best)"
    printf '%s' "Opcion: "
    read reproductor

    case $reproductor in
        1)
            play_with_mplayer "$titulo" "$capitulo" "$m3u8_url"
            ;;
        2)
            play_with_mpv "$titulo" "$capitulo" "$m3u8_url"
            ;;
        *)
            printf '%b\n' "${RED}Opcion invalida, usando MPV por defecto${NC}"
            play_with_mpv "$titulo" "$capitulo" "$m3u8_url"
            ;;
    esac

    return 0
}

printf '%b\n' "${GREEN}Iniciando Anime CLI...${NC}"
printf '%b\n' "${YELLOW}Cargando configuracion...${NC}"

while true; do
    menu_principal
    read opcion

    case $opcion in
        1)
            buscar_anime
            ;;
        2)
            printf '%b\n' "${YELLOW}Opcion disponible para futuras versiones :(${NC}"
            ;;
        3)
            echo ""
            printf '%b\n' "${GREEN}Hasta luego!${NC}"
            echo ""
            exit 0
            ;;
        4)
            eliminarTemporales
            ;;
        *)
            printf '%b\n' "${RED}Opcion invalida${NC}"
            sleep 1
            ;;
    esac

    echo ""
    printf '%s' "Presiona Enter para continuar al menu principal..."
    read
done
