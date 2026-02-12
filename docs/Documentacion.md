# Documentación de funcionamiento interno A-CLI

## 📚 Visión General 

```
A-CLI es un sistema modular donde cada script tiene una responsabilidad única y bien definida
         ↓
    ┌─────────────────────────────────────────────────────────┐
    │                      A-CLI.sh                           │
    │                (Interfax CLI)                  │
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


*Documentación de módulos en proceso - A-CLI v1.1*  
*Última actualización: Febrero 2026*
