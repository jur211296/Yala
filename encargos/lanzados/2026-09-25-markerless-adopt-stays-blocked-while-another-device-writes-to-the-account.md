# El adopt sin marcador no entra mientras otro teléfono siga escribiendo en la cuenta

## Contexto
Cola A autónoma (callejón nube). Acaba de mergear a 2.1 el PR #246 (`adopt-window-late-leader-identity-export-can-duplicate-after-the-remount`): con marcador, lo que un líder desplazado exporta tarde ya no duplica movimientos casables por clave de linaje. Residual de ese PR (`adopt-rekeyed-rows-without-a-unique-lineage-key-still-duplicate`) queda en backlog a la espera del canario — NO lo toques.

Este ticket: `tickets/backlog/markerless-adopt-stays-blocked-while-another-device-writes-to-the-account.md`. Review adversarial de `lineage-coverage-blocks-forever-after-a-row-deleted-during-the-wait`. Arrancas en contexto limpio; lee el ticket entero y el código citado ahí.

## Que se pide
1. Mide cuántos adopts sin marcador llegan con otro teléfono activo (¿el marcador existe en la práctica en flota / en el camino real?).
2. Da una salida que no duplique filas, o deja escrita la decisión de que la espera («espera a iCloud») es el comportamiento correcto — la más robusta / buena práctica, nunca la más simple.
3. Gate verde, PR a 2.1, merge, board del repo al día (`tickets/` + `docs/TICKETS.md`), `/cerrar-total`.

## Que NO hay que tocar
- marketing/, Web/
- El residual `adopt-rekeyed-rows-without-a-unique-lineage-key-still-duplicate` (espera canario)
- No relajar el corte global de forma que un tercer teléfono pueda subir filas ajenas

## Como se sabe que esta bien
- Criterios del ticket cumplidos (medición + salida o decisión escrita)
- Tests / mutantes según el alcance; gate verde; PR mergeado; board e índice al día; `/cerrar-total`

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio (`--solo-crear`) antes de cerrar. Board de proyectos: create/move directo. La regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda suspendida en esta cola: implementa hasta cerrar sin pedir continuar.

Horario Lima diurno (6:00–21:00): si necesitas decisión de producto o de acceso, usa AskUserQuestion. El bot dueño (Frank) contesta con la opción robusta / recomendada; no esperes a Jürgen salvo device/secrets/acceso real o decisión demasiado grave para asumir.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.

## Paso 0

**Medido (2026-09-25).**
- Flota: producción tiene **0 perfiles** (conteo como `postgres` por `apply_migration` + `raise exception`, sin rastro).
  Staging: 6 perfiles, 4 migrados, todos de dogfooding. En Analytics Engine (90 días) no hay ningún evento de este camino:
  el bloqueo solo deja `os_log` (`adoptReconcileAccountRowsMissing`), que no sale del teléfono. ⇒ Hoy no se puede contar en
  flota, y no hay nada que contar.
- Camino real: **el líder no apaga su espejo sin haber exportado el marcador** (`isMarkerExported`, paso 4 del cutover); si
  no lo consigue en 15 min / 72 h vuelve a iCloud y lo borra. Así que «otro teléfono escribe a diario» + «sin marcador» NO
  sale de un líder que terminó. Sale de dos sitios:
  1. El segundo teléfono aún no importó el marcador (import atrasado, iCloud apagado en ese teléfono). Transitorio: al
     llegar el marcador, entra. La espera es correcta.
  2. **El que escribe a diario es un teléfono que ADOPTÓ, en una cuenta cuyo líder nunca exportó su marcador** (se quedó
     sin red o sin iCloud tras el cutover del servidor y murió o abortó). Los adoptadores no escriben marcador, así que el
     tercer teléfono —y el propio líder abortado, que vuelve «por adopt»— se quedan fuera para siempre. Este es el caso del
     ticket, y la espera ahí es mentira: iCloud no va a traer nada.

**Decisiones (auto-contestadas, modo autónomo).**
- D1 · Salida, no espera: **el adoptador releva el marcador.** Si entra sin marcador de la cuenta y con **cobertura
  total** (toda fila viva del backend, fuera de las exentas, está aquí con su identidad), deja su propio
  `CloudMigrationMarker` en iCloud antes de apagar su espejo. Es igual de fuerte que el del líder: todo lo que el backend
  tenía viajó por iCloud ANTES que el marcador, y lo que se escribe en la nube después no toca iCloud, así que no puede
  tener gemela. El siguiente teléfono entra por el camino del marcador. El corte global no se toca.
  Descartadas: mover el corte (reabre el tercer teléfono), el HLC del backend (es de la última escritura, no de la
  creación), un registro de «espejo apagado» en el servidor (falla abierto con un adoptador a medias) y «subir igualmente»
  (decisión de producto que duplica).
- D2 · Sin cobertura total no se releva (el adoptador que entró con filas borradas o casadas por sus nuevas). Residual con
  ticket si queda algo.
- D3 · El aborto del líder borra **solo su marcador** (efecto nuevo `deleteOwnCloudKitMarker`, append-only); la reversa
  sigue borrando todos (la nube deja de mandar). Sin esto, el líder que aborta borraría el marcador relevado.
- D4 · `isMarkerExported` mira **solo el marcador propio**: el paso 4 pregunta si MI marcador llegó, y uno relevado
  importado lo contestaría por él.
- D5 · `serverSeqCut = 0` en el relevado: la reversa cae a barrer desde 0, correcto y más caro. No se inventa un corte.
- D6 · Medir en adelante: canario `cloudAdoptLineageBlocked` (una vez por proceso y motivo, con `activeWriter` si el
  backend se escribió en las últimas 24 h) y `cloudAdoptMarkerRelayed`.
- D7 · Sin espera del export dentro del adopt: el espejo sigue vivo hasta el relanzamiento; si no llega a salir, queda
  el comportamiento de hoy (esperar), nunca un duplicado.
- Review adversarial: sí (sync, migración).
