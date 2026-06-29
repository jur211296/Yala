# Post diario de Yala para Instagram

Automatización **local**: cada mañana renderiza un post **nuevo** (1080×1350 (4:5 vertical)) y lo envía por Telegram
con un caption sugerido, listo para publicar. **Rota formatos** para que el feed no se sienta repetido.

## Formatos (rotación marketera)
El pool (`content.json`) está intercalado a propósito — nunca dos del mismo tipo seguidos, con una
**funcionalidad cada ~3 posts**:
- **Funcionalidad** (`feature`) — destaca una pantalla real de la app (con screenshot).
- **Tip / Dato** — consejo o realidad relatable (gráfico).
- **Recordatorio** (`reminder`) — engagement: "¿ya registraste hoy?".
- **Frase / Reto** — branding y micro-retos.

## Cómo funciona
1. `state.json` guarda el último índice enviado.
2. `send-daily.mjs` toma el siguiente del pool, llama a `render-post.mjs` (genera el PNG con Chrome
   headless) y lo envía por Telegram (`sendPhoto`). **Solo avanza el índice si el envío fue OK.**
3. Token leído de `~/.claude/channels/telegram/.env` (no se duplica). Chat: `8778292009`.
4. `launchd` lo dispara cada día a las **9:00 AM** (agente `com.yala.dailypost`).

## Archivos
- `content.json` — el pool de posts (todos los formatos). Edítalo para añadir/cambiar.
- `render-post.mjs` — renderiza un post (con o sin screenshot) a PNG 1080×1350 (4:5 vertical).
- `send-daily.mjs` — orquestador (rota → render → Telegram).
- `state.json`, `out/`, `daily.log`, `daily.err.log`.
- `~/Library/LaunchAgents/com.yala.dailypost.plist` — el agente launchd.

## Añadir contenido (`content.json`)
Campos: `id`, `kind` (`feature|tip|dato|reminder|frase|reto`), `tag`, `emoji`, `title`, `highlight`,
`sub`, `accent` (`cyan|pink|indigo|violet`), `caption`. Para **funcionalidades** añade además:
`screenshot` (nombre del PNG en `generator/public/screenshots/es/`, sin extensión) y `shot`
(`tilted` o `full`). Mantén el orden intercalado (no dos del mismo tipo seguidos).

## Tareas comunes
- **Probar ahora:** `node send-daily.mjs`
- **Solo renderizar:** `node render-post.mjs <índice>` → PNG en `out/`
- **Cambiar la hora:** edita `Hour`/`Minute` en el plist y recarga (bootout + bootstrap).
- **Pausar:** `launchctl bootout gui/$(id -u)/com.yala.dailypost`
- **Reactivar:** `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.yala.dailypost.plist`

## Limitaciones
- Corre solo si la Mac está **encendida/despierta** a la hora fijada (si dormía, se ejecuta al despertar).
- Contenido **curado que rota** (no IA en vivo): calidad de marca garantizada. 33 posts ≈ **un mes** antes de repetir.
- Envía a **Telegram** (tú publicas en IG). No auto-publica en Instagram — eso requeriría la API de Meta.
