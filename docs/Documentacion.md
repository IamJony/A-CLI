# Documentación de funcionamiento interno A-CLI

## 📚 Visión General 

```
A-CLI es un sistema modular donde cada script tiene una responsabilidad única y bien definida
         ↓
    ┌─────────────────────────────────────────────────────────┐
    │                      A-CLI.sh                           │
    │                (Orquestador Principal Interfax CLI)                  │
    └─────────────────────────────────────────────────────────┘
         ↓               ↓               ↓               ↓
    ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐
    │ config.sh │  │ search.sh │  │chapters.sh│  │servers.sh │
    │(Config)   │  │(Búsqueda) │  │(Obtener numero de capítulos)│  │(Servidores "videos embebidos")│
    └───────────┘  └───────────┘  └───────────┘  └───────────┘
                                                    ↓
                                              ┌───────────┐
                                              │ m3u8.sh   │
                                              │(Extracción│
                                              └───────────┘
                                                    ↓
                                              ┌───────────┐
                                              │   mpv     │
                                              │(Reproductor│
                                              └───────────┘
```

---

# 🎬 Módulo 1: `config.sh` - Configuración y Autenticación

## Propósito
Configuración global, manejo de cookies, tokens CSRF y URLs base.

## Diagrama de Flujo Interno

```
[Inicio config.sh]
       ↓
[Crear TEMP_DIR] → /tmp/TEMP_A-CLI/
       ↓
[Definir URLs] → Decodificar BASE_URL
       ↓
[Definir USER_AGENT]
       ↓
[verify_cookies()] ──Sí──→ [load_token()]
       ↓ No                     ↓
[get_cookies()] ←──── [CSRF_TOKEN]
       ↓
[check_token()] → [Exportar CSRF_TOKEN]
```

## Variables de Estado

```bash
# Estados posibles del token
TOKEN_VALIDO=0     # Token existe y < 30 minutos
TOKEN_EXPIRADO=1   # Token existe pero > 30 minutos
TOKEN_INEXISTE=2   # No hay archivo de token
```

## Mecanismo de Autenticación

```bash
# Ciclo de vida del token
1. verify_cookies() → Verifica archivo y edad
2. get_cookies() → Obtiene nuevo token del HTML
   ↓
   Busca: <meta name="csrf-token" content="abc123...">
   ↓
   Guarda: CSRF_TOKEN=abc123... en tokens.txt
3. check_token() → Punto de entrada único
```

## Dependencias y Efectos Colaterales

| Función | Modifica | Depende de |
|---------|----------|------------|
| `get_cookies()` | `COOKIE_FILE`, `TOKEN_FILE`, `CSRF_TOKEN` | `curl`, `BASE_URL` |
| `verify_cookies()` | Ninguna | `stat`, `date` |
| `load_token()` | `CSRF_TOKEN` | `TOKEN_FILE` |

---

# 🔍 Módulo 2: `search.sh` - Búsqueda de Animes

## Propósito
Realizar búsquedas en el sitio y devolver resultados estructurados en JSON.

## Diagrama de Secuencia

```
[search.sh "nombre anime"]
       ↓
[check_token] → Autenticación
       ↓
[URL encode] → "one piece" → "one+piece"
       ↓
[POST Request]
├── URL: $API_SEARCH
├── Data: _token=CSRF_TOKEN&q=SEARCH_TERM
└── Headers: Referer, X-Requested-With
       ↓
[Respuesta JSON] → jq . > search.json
       ↓
[Estructura del JSON]
[
  {
    "id": "1117",
    "title": "One Piece",
    "slug": "one-piece",
    "type": "Serie",
    "status": "En emision"
  },
  ...
]
```

## Procesamiento de Datos

```bash
# Flujo de transformación
Término búsqueda → Codificación URL → Petición POST → JSON crudo → JSON filtrado
     "naruto"    →   "naruto"      →    curl      →   raw.json   →  search.json
```

## Interpretación del JSON de Salida

```json
{
  "id": "123",        // Usado en chapters.sh
  "title": "Título",  // Mostrado al usuario
  "slug": "slug",     // Usado en URL: base_url/slug/1/
  "type": "Serie",    // Identificar películas (no soportadas)
  "status": "Finalizado" // Estado del anime
}
```

## Casos Edge

```bash
# Sin resultados
echo "[]" > search.json  # Array vacío

# Error de token
{
  "error": "Token mismatch"
}

# Timeout
curl: (28) Connection timed out
```

---

# 📊 Módulo 3: `chapters.sh` - Contador de Capítulos

## Propósito
Obtener el número total de capítulos de un anime específico.

## Protocolo de Comunicación

```
Cliente (chapters.sh)              Servidor (API)
       |                                  |
       | POST /ajax/episodes/1117/1      |
       | ────────────────────────────────→|
       |                                  |
       | Headers:                         |
       | - Referer: anime-url            |
       | - X-CSRF-TOKEN: abc123          |
       |                                  |
       | Body: _token=abc123             |
       |                                  |
       | Response: {"total": 1122}       |
       | ←────────────────────────────────|
       |                                  |
       | jq .total → "1122"              |
```

## Anatomía de la Petición

```bash
# URL generada
API_CHAPTERS="$BASE_URL/ajax/episodes"
URL_COMPLETA="$API_CHAPTERS/$ANIME_ID/$CHAPTER_NUM"
# Ejemplo: https://jkanime.net/ajax/episodes/1117/1

# Payload
--data-raw "_token=eyJpdiI6Im5XcHZ..."
```

## Respuesta y Procesamiento

```bash
# Respuesta exitosa
{"total":1122}  # jq .total → 1122

# Respuesta error (token inválido)
{
  "error": "CSRF token mismatch",
  "message": "Invalid token"
}

# Respuesta (anime no existe)
{"total":0}
```

## Relación con Otros Módulos

```
A-CLI.sh → chapters.sh → Número total de capítulos
    ↓
   Usado para validar selección del usuario
    ↓
   Límite superior en el selector de capítulos
```

---

# 🖥️ Módulo 4: `servers.sh` - Extracción de Servidores

## Propósito
Analizar el HTML del capítulo y extraer todas las URLs de servidores de video.

## Arquitectura de Extracción

```
[anime.html]
     ↓
[Extracción Dual]
     ├── [Servidores Principales] → grep "jkplayer/um"
     │        ↓
     │    URLs directas: https://cdn.jkdesa.com/...
     │
     └── [Servidores Embebidos] → grep '"remote":"'
              ↓
          Base64 decode: echo "aHR0c..." | base64 -d
              ↓
          URLs decodificadas: https://streamtape.com/...
```

## Estructuras de Datos

```bash
# Arrays utilizados
declare -a MAIN_SERVERS      # Servidores jkplayer/um
declare -a EMBEDDED_SERVERS  # Servidores decodificados de base64
declare -a ALL_SERVERS       # Combinación de ambos

# Ejemplo de llenado
MAIN_SERVERS=(
  "https://cdn.jkdesa.com/jkplayer/um/player.php?id=123"
  "https://cdn.jkdesa.com/jkplayer/um/player2.php?id=456"
)

EMBEDDED_SERVERS=(
  "https://streamtape.com/e/abc123/"
  "https://mega.nz/embed/#!xyz789"
)
```

## Procesamiento de Base64

```bash
# Flujo de decodificación
'"remote":"aHR0cHM6Ly9zdHJlYW10YXBlLmNvbS9lL2FiYzEyMy8="'  # HTML raw
                    ↓
            echo "aHR0cHM6Ly9zdHJlYW10YXBlLmNvbS9lL2FiYzEyMy8="  # Extracción
                    ↓
            base64 -d  # Decodificación
                    ↓
"https://streamtape.com/e/abc123/"  # URL real
```

## Generación de JSON

```json
{
  "servers": [
    "https://cdn.jkdesa.com/jkplayer/um/player.php?id=123",
    "https://streamtape.com/e/abc123/"
  ],
  "metadata": {
    "total_servers": 2,
    "main_servers": 1,
    "embedded_servers": 1,
    "extracted_at": "2026-02-11T15:30:45+00:00"
  }
}
```

---

# 🎯 Módulo 5: `m3u8.sh` - Extracción de Stream

## Propósito
Obtener la URL del archivo .m3u8 desde cualquier servidor de video embebido.

## Sistema de Métodos de Extracción

```
[URL del Servidor]
       ↓
[Descargar HTML del reproductor]
       ↓
[11 Métodos de Extracción en Cascada]
       ↓
├── Método 1: atob() → Decodificación base64
├── Método 2: Variables JS → var video = 'url.m3u8'
├── Método 3: URLs directas → https://*.m3u8
├── Método 4: unescape() → %48%54%54%50%53...
├── Método 5: eval() packed → eval(function(p,a,c,k,e,d)
├── Método 6: JSON objects → {"file":"url.m3u8"}
├── Método 7: iframe + recursión → Seguir nested iframes
├── Método 8: Comentarios HTML → <!-- url.m3u8 -->
├── Método 9: decodeURIComponent() → %7B%22file%22%3A...
├── Método 10: videojs data-setup → data-setup='{"sources":[...]}'
└── Método 11: Player config → file: 'url.m3u8'
       ↓
[URL .m3u8] → [stream.m3u8] → [stream.json]
```

## Ejemplos de Patrones por Método

### Método 1: atob()
```javascript
// HTML original
atob('aHR0cHM6Ly9jZG4uamtkZXNhLmNvbS9oU0hQc2pkLm0zdTg=')

// Decodificado
https://cdn.jkdesa.com/hSHPjsd.m3u8
```

### Método 4: unescape()
```javascript
// HTML original
unescape('https%3A%2F%2Fcdn.jkdesa.com%2Fvideo.m3u8')

// Decodificado
https://cdn.jkdesa.com/video.m3u8
```

### Método 5: Packer
```javascript
eval(function(p,a,c,k,e,d){...}('...',10,20,'video|m3u8|https'.split('|')))
```

### Método 7: Recursión
```
URL original: https://cdn.jkdesa.com/jkplayer/um/player.php?id=123
    ↓
Iframe: <iframe src="/embed/player2.php?id=123">
    ↓
Normalizar: https://cdn.jkdesa.com/embed/player2.php?id=123
    ↓
Recursión: ./m3u8.sh "https://cdn.jkdesa.com/embed/player2.php?id=123"
    ↓
URL m3u8 encontrada
```

## Sistema de Debug

```bash
# Modos de operación
./m3u8.sh "URL"           # Modo silencioso (solo URL)
./m3u8.sh "URL" -d       # Modo debug (explicativo)
./m3u8.sh "URL" --debug  # Modo debug detallado

# Output debug
🔍 Método 1 falló, probando método 2...
🔍 Método 2 exitoso: https://cdn.jkdesa.com/hSHPjsd.m3u8
✅ URL m3u8 encontrada
```

## Archivos Generados

```bash
# stream.m3u8 (simple)
https://cdn.jkdesa.com/stream_720p.m3u8

# stream.json (estructurado)
{
  "m3u8": "https://cdn.jkdesa.com/stream_720p.m3u8"
}
```

---

# 🎮 Módulo 6: `A-CLI.sh` - Orquestador Principal

## Propósito
Interfaz de usuario y coordinación de todos los módulos.

## Máquina de Estados

```
[INICIO]
    ↓
[MENÚ PRINCIPAL]
    ├── [1 Buscar] → [ESTADO BÚSQUEDA]
    ├── [2 URL]    → [NO IMPLEMENTADO]
    ├── [3 Salir]  → [TERMINAR]
    └── [4 Limpiar] → [LIMPIEZA]

[ESTADO BÚSQUEDA]
    ↓
[search.sh] → ¿Éxito? → Sí → [SELECCIÓN]
               ↓ No         ↓
          [REINTENTAR]      ↓
                       [chapters.sh]
                            ↓
                    [SELECCIÓN CAPÍTULO]
                            ↓
                    ┌────────┴────────┐
                    ↓                 ↓
                [REPRODUCIR]    [SOLO SERVIDORES]
                    ↓                 ↓
              [servers.sh]      [servers.sh]
                    ↓                 ↓
              [m3u8.sh]         [servers.json]
                    ↓
              [mpv play]
```

## Gestión de Estado de Usuario

```bash
# Variables de sesión
anime_id="123"        # ID numérico para API
anime_slug="one-piece" # Slug para URLs
anime_title="One Piece" # Título para mostrar
total_capitulos="1122" # Límite de selección
capitulo_actual="5"   # Último visto
```

## Sistema de Historial

```json
// /home/j/historial.json
{
  "titulo": "One Piece",
  "slug": "one-piece",
  "total_capitulos": "1122",
  "capitulo_visto": "5",
  "favorito": "false"
}
```

## Validaciones de Usuario

```bash
# Sistema de validación de entrada
case "$capitulo" in
    0)     return 0 ;;                    # Volver al menú
    00)    return 1 ;;                    # Nueva búsqueda
    "")    echo "No ingresaste nada" ;;   # Vacío
    *[!0-9]*) echo "Solo números" ;;      # No numérico
    *)      # Capítulo válido
            if [ "$capitulo" -lt 1 ] || [ "$capitulo" -gt "$total_capitulos" ]; then
                echo "Fuera de rango"
            fi
            ;;
esac
```

---

# 📊 Matriz de Responsabilidades

| Módulo | Responsabilidad | Entrada | Salida | Formato |
|--------|----------------|---------|--------|---------|
| **config.sh** | Autenticación, configuración | Ninguna | `CSRF_TOKEN`, `COOKIE_FILE` | Variables env |
| **search.sh** | Búsqueda de animes | Término texto | `search.json` | JSON array |
| **chapters.sh** | Total capítulos | `anime_id` | Número entero | Plain text |
| **servers.sh** | Extraer servidores | `anime.html` | `servers.json` | JSON object |
| **m3u8.sh** | Extraer stream | URL servidor | `stream.m3u8` | URL (texto) |
| **A-CLI.sh** | Orquestación, UI | Input usuario | Reproducción | N/A |

---

# 🔄 Flujo de Datos entre Módulos

```
[USUARIO] → "one piece"
    ↓
[A-CLI.sh] → llama → [search.sh] → search.json
    ↓                          ↓
[anime_id=1117, slug=one-piece] ← jq
    ↓
[A-CLI.sh] → llama → [chapters.sh 1117] → "1122"
    ↓
[total_capitulos=1122]
    ↓
[A-CLI.sh] → descarga → anime.html (capítulo 5)
    ↓
[A-CLI.sh] → llama → [servers.sh] → servers.json
    ↓                          ↓
[primer_servidor] ← jq '.servers[0]'
    ↓
[A-CLI.sh] → llama → [m3u8.sh URL] → stream.m3u8
    ↓                          ↓
[m3u8_url] ← cat stream.m3u8
    ↓
[mpv "$m3u8_url"]
```

---

# 🧪 Testing por Módulo

## Test config.sh
```bash
# Verificar decodificación
source config.sh
echo "$BASE_URL"  # Debe mostrar: https://jkanime.net

# Verificar token
rm -f "$TOKEN_FILE"
check_token
echo "$CSRF_TOKEN"  # Debe mostrar token nuevo
```

## Test search.sh
```bash
# Probar búsqueda
./search.sh "naruto"
jq '.[0]' /tmp/TEMP_A-CLI/search.json  # Ver primer resultado

# Probar sin resultados
./search.sh "animequenoexiste123456"
[ -s /tmp/TEMP_A-CLI/search.json ] && echo "Tiene datos"
```

## Test chapters.sh
```bash
# ID conocido
./chapters.sh 1117  # Debe mostrar número > 1000

# ID inválido
./chapters.sh 999999  # Debe mostrar 0 o error
```

## Test servers.sh
```bash
# Primero descargar página de ejemplo
./A-CLI.sh  # Navegar hasta seleccionar capítulo sin reproducir

# Luego probar extracción
./servers.sh
jq '.servers | length' /tmp/TEMP_A-CLI/servers.json  # Total servidores
```

## Test m3u8.sh
```bash
# URL de ejemplo (jkplayer)
./m3u8.sh "https://cdn.jkdesa.com/jkplayer/um/player.php?id=1117" --debug




*Documentación de módulos - A-CLI v1.0*  
*Última actualización: Febrero 2026*
